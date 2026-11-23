import assert from 'node:assert/strict';
import test from 'node:test';

import {
  mfaBlockReason,
  requiresMfaChallenge,
} from '../functions/_shared/mfa-auth.ts';

function tokenWithAal(aal) {
  const payload = Buffer.from(JSON.stringify({ aal })).toString('base64url');
  return `header.${payload}.signature`;
}

test('privileged accounts without a verified factor must enroll first', () => {
  const user = { app_metadata: { role: 'super_admin' }, factors: [] };

  assert.equal(mfaBlockReason(user, tokenWithAal('aal1')), 'enrollment_required');
  assert.equal(requiresMfaChallenge(user, tokenWithAal('aal1')), true);
});

test('privileged accounts with a verified factor require AAL2', () => {
  const user = {
    app_metadata: { role: 'moderator' },
    factors: [{ status: 'verified' }],
  };

  assert.equal(mfaBlockReason(user, tokenWithAal('aal1')), 'challenge_required');
  assert.equal(mfaBlockReason(user, tokenWithAal('aal2')), null);
});

test('regular users retain opt-in MFA behavior', () => {
  const user = { app_metadata: {}, factors: [] };

  assert.equal(mfaBlockReason(user, tokenWithAal('aal1')), null);
  assert.equal(requiresMfaChallenge(user, tokenWithAal('aal1')), false);
});

test('regular users with a verified factor still require AAL2', () => {
  const user = { app_metadata: {}, factors: [{ status: 'verified' }] };

  assert.equal(mfaBlockReason(user, tokenWithAal('aal1')), 'challenge_required');
  assert.equal(mfaBlockReason(user, tokenWithAal('aal2')), null);
});
