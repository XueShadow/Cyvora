import {
  createClient,
  type SupabaseClient,
} from 'https://esm.sh/@supabase/supabase-js@2';
import { mfaBlockReason } from '../_shared/mfa-auth.ts';
import { readJsonObjectBody } from '../_shared/request-body.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-supabase-api-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function createInvitationToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join(
    '',
  );
}

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, '0'),
  ).join('');
}

async function handleRequest(request: Request) {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed.' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Family invitations: Supabase environment is incomplete.');
    return jsonResponse(500, { error: 'Invitation service is not configured.' });
  }

  const authorization = request.headers.get('Authorization');
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) {
    return jsonResponse(401, { error: 'Sign in to manage family invitations.' });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const {
    data: { user },
    error: authError,
  } = await admin.auth.getUser(accessToken);
  if (authError || !user || !user.email) {
    return jsonResponse(401, { error: 'Your session is invalid or expired.' });
  }
  const mfaBlock = mfaBlockReason(user, accessToken);
  if (mfaBlock) {
    return jsonResponse(
      403,
      {
        error: mfaBlock === 'enrollment_required'
          ? 'Enroll a verified authenticator before using this service.'
          : 'Complete two-factor authentication before using this service.',
      },
    );
  }

  let parsedBody: Awaited<ReturnType<typeof readJsonObjectBody>>;
  try {
    parsedBody = await readJsonObjectBody(request, 16 * 1024);
  } catch {
    return jsonResponse(400, { error: 'Request body must be valid JSON.' });
  }
  if (!parsedBody.ok) {
    return jsonResponse(parsedBody.status, { error: parsedBody.error });
  }
  const body = parsedBody.value;

  if (body.action === 'invite') {
    return await sendInvitation(admin, user.id, user.email, body);
  }
  if (body.action === 'revoke') {
    return await revokeInvitation(admin, user.id, body);
  }
  if (body.action === 'accept') {
    return await acceptInvitation(admin, user, body);
  }
  return jsonResponse(400, { error: 'Unknown invitation action.' });
}

Deno.serve(async (request) => {
  try {
    return await handleRequest(request);
  } catch (error) {
    console.error('Family invitations: unexpected request failure.', error);
    return jsonResponse(500, {
      error: 'The invitation service could not complete this request.',
    });
  }
});

async function revokeInvitation(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
) {
  const familyId = typeof body.familyId === 'string' ? body.familyId : '';
  const email =
    typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      familyId,
    ) ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return jsonResponse(400, { error: 'Choose a valid pending invitation.' });
  }

  const { data: membership, error: membershipError } = await admin
    .from('family_members')
    .select('family_id')
    .eq('family_id', familyId)
    .eq('user_id', userId)
    .eq('role', 'owner')
    .maybeSingle();
  if (membershipError) {
    console.error('Family invitations: owner lookup failed.', membershipError);
    return jsonResponse(500, { error: 'Could not verify family ownership.' });
  }
  if (!membership) {
    return jsonResponse(403, {
      error: 'Only the family owner can cancel an invitation.',
    });
  }

  const { data: invitation, error: deleteError } = await admin
    .from('family_invites')
    .delete()
    .eq('family_id', familyId)
    .eq('invited_email', email)
    .is('accepted_at', null)
    .select('id')
    .maybeSingle();
  if (deleteError) {
    console.error('Family invitations: invite cancellation failed.', deleteError);
    return jsonResponse(500, { error: 'Could not cancel this invitation.' });
  }
  if (!invitation) {
    return jsonResponse(404, { error: 'Pending invitation was not found.' });
  }
  return jsonResponse(200, { message: 'Invitation canceled.' });
}

async function sendInvitation(
  admin: SupabaseClient,
  userId: string,
  userEmail: string | undefined,
  body: Record<string, unknown>,
) {
  const familyId = typeof body.familyId === 'string' ? body.familyId : '';
  const email =
    typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      familyId,
    )
  ) {
    return jsonResponse(400, { error: 'Choose a valid family group.' });
  }
  if (
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return jsonResponse(400, { error: 'Enter a valid email address.' });
  }
  if (userEmail?.toLowerCase() === email) {
    return jsonResponse(409, {
      error: 'You are already a member of this family group.',
    });
  }

  const { data: membership, error: membershipError } = await admin
    .from('family_members')
    .select('family_id')
    .eq('family_id', familyId)
    .eq('user_id', userId)
    .eq('role', 'owner')
    .maybeSingle();
  if (membershipError) {
    console.error('Family invitations: owner lookup failed.', membershipError);
    return jsonResponse(500, { error: 'Could not verify family ownership.' });
  }
  if (!membership) {
    return jsonResponse(403, {
      error: 'Only the family owner can invite members.',
    });
  }

  const { error: expiredInviteError } = await admin
    .from('family_invites')
    .delete()
    .eq('family_id', familyId)
    .eq('invited_email', email)
    .is('accepted_at', null)
    .lt('expires_at', new Date().toISOString());
  if (expiredInviteError) {
    console.error(
      'Family invitations: expired invitation cleanup failed.',
      expiredInviteError,
    );
    return jsonResponse(500, { error: 'Could not create the invitation.' });
  }

  const token = createInvitationToken();
  const tokenHash = await hashToken(token);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    .toISOString();
  const { data: invitationId, error: inviteError } = await admin.rpc(
    'create_family_invite',
    {
      p_family_id: familyId,
      p_invited_email: email,
      p_token_hash: tokenHash,
      p_invited_by: userId,
      p_expires_at: expiresAt,
    },
  );
  if (inviteError) {
    if (inviteError.message === 'family_invite_rate_limit') {
      return jsonResponse(429, {
        error: 'This family has reached the hourly invitation limit.',
      });
    }
    if (inviteError.code === '42501') {
      return jsonResponse(403, {
        error: 'Only the family owner can invite members.',
      });
    }
    if (inviteError.code === '23505') {
      return jsonResponse(409, {
        error: 'That address already has a pending invitation.',
      });
    }
    console.error('Family invitations: invite creation failed.', inviteError);
    return jsonResponse(500, { error: 'Could not create the invitation.' });
  }
  if (!invitationId) {
    console.error('Family invitations: invite creation returned no ID.');
    return jsonResponse(500, { error: 'Could not create the invitation.' });
  }

  return jsonResponse(200, {
    invitationId,
    emailSent: false,
    invitationCode: token,
    expiresAt,
    deliveryIssue:
      'Email delivery is disabled; share the invitation code directly.',
    message: 'Share this invitation code with the invited family member.',
  });
}

async function acceptInvitation(
  admin: SupabaseClient,
  user: { id: string },
  body: Record<string, unknown>,
) {
  const token = typeof body.token === 'string' ? body.token.trim() : '';
  if (!/^[0-9a-f]{64}$/i.test(token)) {
    return jsonResponse(400, { error: 'Enter a valid invitation code.' });
  }

  const { data: familyId, error } = await admin.rpc('consume_family_invite', {
    invite_token_hash: await hashToken(token),
    joining_user_id: user.id,
  });
  if (error) {
    const knownError =
      error.message.includes('invalid or expired') ||
      error.message.includes('verified email address');
    if (knownError) {
      return jsonResponse(400, { error: error.message });
    }
    if (error.code === '23505') {
      return jsonResponse(409, {
        error: 'This account already belongs to a family group.',
      });
    }
    console.error('Family invitations: invite acceptance failed.', error);
    return jsonResponse(500, { error: 'Could not accept this invitation.' });
  }

  return jsonResponse(200, {
    familyId,
    message: 'You joined the family group.',
  });
}
