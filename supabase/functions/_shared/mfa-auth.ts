type AuthFactor = {
  status?: string;
};

type AuthUser = {
  factors?: AuthFactor[] | null;
  app_metadata?: {
    role?: string | null;
  } | null;
};

export type MfaBlockReason = 'enrollment_required' | 'challenge_required';

function accessTokenAal(accessToken: string): string | null {
  const encodedPayload = accessToken.split('.')[1];
  if (!encodedPayload) return null;

  try {
    const normalized = encodedPayload.replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
    const payload = JSON.parse(atob(padded)) as { aal?: unknown };
    return typeof payload.aal === 'string' ? payload.aal : null;
  } catch {
    return null;
  }
}

export function requiresMfaChallenge(
  user: AuthUser,
  accessToken: string,
): boolean {
  return mfaBlockReason(user, accessToken) !== null;
}

export function mfaBlockReason(
  user: AuthUser,
  accessToken: string,
): MfaBlockReason | null {
  const hasVerifiedFactor =
    user.factors?.some((factor) => factor.status === 'verified') ?? false;
  const isPrivilegedAdmin = [
    'super_admin',
    'admin',
    'moderator',
    'support_admin',
  ].includes(user.app_metadata?.role ?? '');

  if (isPrivilegedAdmin && !hasVerifiedFactor) return 'enrollment_required';
  if (hasVerifiedFactor && accessTokenAal(accessToken) !== 'aal2') {
    return 'challenge_required';
  }
  return null;
}
