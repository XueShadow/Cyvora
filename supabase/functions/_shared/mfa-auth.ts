type AuthFactor = {
  status?: string;
};

type AuthUser = {
  factors?: AuthFactor[] | null;
};

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
  const hasVerifiedFactor =
    user.factors?.some((factor) => factor.status === 'verified') ?? false;
  return hasVerifiedFactor && accessTokenAal(accessToken) !== 'aal2';
}
