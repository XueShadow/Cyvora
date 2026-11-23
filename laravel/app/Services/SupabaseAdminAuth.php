<?php

namespace App\Services;

use App\Admin\AdminRole;
use App\Exceptions\AdminAccessDeniedException;

final class SupabaseAdminAuth
{
    public function __construct(public SupabaseAdminClient $client) {}

    /**
     * @return array<string, mixed>
     */
    public function signIn(string $email, string $password): array
    {
        $session = $this->client->signIn($email, $password);

        if (is_string($session['access_token'] ?? null)) {
            $session['user'] = $this->client->currentUser($session['access_token']);
        }

        return $this->assertAdminSession($session);
    }

    /**
     * @return array<string, mixed>
     */
    public function user(string $accessToken): array
    {
        return $this->client->currentUser($accessToken);
    }

    /**
     * @return array<string, mixed>
     */
    public function refresh(string $refreshToken): array
    {
        $session = $this->client->refreshSession($refreshToken);

        if (is_string($session['access_token'] ?? null)) {
            $session['user'] = $this->client->currentUser($session['access_token']);
        }

        return $this->assertAdminSession($session);
    }

    /**
     * @return array<string, mixed>
     */
    public function challenge(string $accessToken, string $factorId): array
    {
        return $this->client->createMfaChallenge($accessToken, $factorId);
    }

    /**
     * @return array<string, mixed>
     */
    public function enrollTotpFactor(string $accessToken): array
    {
        return $this->client->enrollTotpFactor($accessToken);
    }

    public function removeFactor(string $accessToken, string $factorId): void
    {
        $this->client->removeMfaFactor($accessToken, $factorId);
    }

    /**
     * @param  array<string, mixed>  $user
     */
    public function discardUnverifiedFactors(array $user, string $accessToken): void
    {
        $factors = $user['factors'] ?? [];
        if (! is_array($factors)) {
            return;
        }

        foreach ($factors as $factor) {
            if (
                is_array($factor)
                && ($factor['status'] ?? null) !== 'verified'
                && is_string($factor['id'] ?? null)
            ) {
                $this->removeFactor($accessToken, $factor['id']);
            }
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function verifyChallenge(
        string $accessToken,
        string $factorId,
        string $challengeId,
        string $code,
    ): array {
        $session = $this->client->verifyMfaChallenge(
            $accessToken,
            $factorId,
            $challengeId,
            $code,
        );

        if (is_string($session['access_token'] ?? null)) {
            $session['user'] = $this->client->currentUser($session['access_token']);
        }

        $session = $this->assertAdminSession($session);
        if (! $this->mfaIsSatisfied($session['user'], $session['access_token'])) {
            throw new AdminAccessDeniedException;
        }

        return $session;
    }

    /**
     * @param  array<string, mixed>  $user
     */
    public function role(array $user): ?AdminRole
    {
        $appMetadata = $user['app_metadata'] ?? [];

        return is_array($appMetadata)
            ? AdminRole::fromSupabase($appMetadata['role'] ?? null)
            : null;
    }

    /**
     * @param  array<string, mixed>  $user
     */
    public function requiresMfa(array $user, string $accessToken): bool
    {
        return $this->role($user) !== null
            && $this->hasVerifiedFactor($user)
            && $this->tokenAal($accessToken) !== 'aal2';
    }

    /**
     * @param  array<string, mixed>  $user
     */
    public function requiresMfaEnrollment(array $user): bool
    {
        return $this->role($user) !== null && ! $this->hasVerifiedFactor($user);
    }

    /**
     * @param  array<string, mixed>  $user
     */
    public function mfaIsSatisfied(array $user, string $accessToken): bool
    {
        return $this->role($user) !== null
            && $this->hasVerifiedFactor($user)
            && $this->tokenAal($accessToken) === 'aal2';
    }

    /**
     * @param  array<string, mixed>  $user
     */
    public function hasVerifiedFactor(array $user): bool
    {
        $factors = $user['factors'] ?? [];

        return is_array($factors) && collect($factors)->contains(
            fn (mixed $factor): bool => is_array($factor)
                && ($factor['status'] ?? null) === 'verified',
        );
    }

    /**
     * @param  array<string, mixed>  $user
     * @return array<int, array{id: string, factor_type: string, friendly_name: string|null}>
     */
    public function verifiedFactors(array $user): array
    {
        $factors = $user['factors'] ?? [];
        if (! is_array($factors)) {
            return [];
        }

        $verified = [];
        foreach ($factors as $factor) {
            if (
                ! is_array($factor)
                || ($factor['status'] ?? null) !== 'verified'
                || ! is_string($factor['id'] ?? null)
                || ! is_string($factor['factor_type'] ?? null)
            ) {
                continue;
            }

            $verified[] = [
                'id' => $factor['id'],
                'factor_type' => $factor['factor_type'],
                'friendly_name' => is_string($factor['friendly_name'] ?? null)
                    ? $factor['friendly_name']
                    : null,
            ];
        }

        return $verified;
    }

    /**
     * @param  array<string, mixed>  $session
     * @return array<string, mixed>
     */
    public function assertAdminSession(array $session): array
    {
        $user = $session['user'] ?? null;
        if (
            ! is_array($user)
            || ! is_string($user['id'] ?? null)
            || ! is_string($user['email'] ?? null)
            || ! is_string($user['email_confirmed_at'] ?? null)
            || $user['email_confirmed_at'] === ''
            || ! is_string($session['access_token'] ?? null)
            || $session['access_token'] === ''
            || ! is_string($session['refresh_token'] ?? null)
            || $session['refresh_token'] === ''
        ) {
            throw new AdminAccessDeniedException;
        }

        if ($this->role($user) === null) {
            throw new AdminAccessDeniedException;
        }

        $session['expires_at'] = now()->timestamp + max(0, (int) ($session['expires_in'] ?? 0));

        return $session;
    }

    private function tokenAal(string $accessToken): ?string
    {
        $parts = explode('.', $accessToken);
        if (! isset($parts[1])) {
            return null;
        }

        $normalized = strtr($parts[1], '-_', '+/');
        $payload = base64_decode(str_pad($normalized, (int) (ceil(strlen($normalized) / 4) * 4), '='), true);
        if (! is_string($payload)) {
            return null;
        }

        $claims = json_decode($payload, true);

        return is_array($claims) && is_string($claims['aal'] ?? null)
            ? $claims['aal']
            : null;
    }
}
