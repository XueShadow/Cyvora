<?php

namespace App\Admin;

use App\Exceptions\AdminAccessDeniedException;
use App\Exceptions\AdminMfaRequiredException;
use App\Exceptions\SupabaseRequestException;
use App\Services\SupabaseAdminAuth;
use App\Services\SupabaseAdminRepository;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Log;
use JsonException;

final class AdminSession
{
    private const SESSION_KEY = 'admin.auth';

    private const PENDING_KEY = 'admin.pending_auth';

    private const PENDING_ENROLLMENT_KEY = 'admin.pending_enrollment';

    private const PENDING_REAUTH_KEY = 'admin.pending_reauth';

    public function __construct(
        private SupabaseAdminAuth $auth,
        private SupabaseAdminRepository $repository,
    ) {}

    /**
     * @param  array<string, mixed>  $session
     */
    public function store(Request $request, array $session): AdminIdentity
    {
        $session = $this->auth->assertAdminSession($session);
        $user = $session['user'];

        if (! $this->auth->mfaIsSatisfied($user, $session['access_token'])) {
            throw new AdminMfaRequiredException;
        }

        $session['mfa_verified_at'] = now()->timestamp;
        $request->session()->regenerate(true);
        $this->write($request, self::SESSION_KEY, $session);
        $request->session()->forget([
            self::PENDING_KEY,
            self::PENDING_ENROLLMENT_KEY,
            self::PENDING_REAUTH_KEY,
        ]);

        return $this->identity($user);
    }

    /**
     * @param  array<string, mixed>  $session
     * @return array<int, array{id: string, factor_type: string, friendly_name: string|null}>
     */
    public function beginMfa(Request $request, array $session): array
    {
        $session = $this->auth->assertAdminSession($session);
        $user = $session['user'];

        if (! $this->auth->requiresMfa($user, $session['access_token'])) {
            throw new AdminAccessDeniedException;
        }

        $factors = $this->auth->verifiedFactors($user);
        if ($factors === []) {
            throw new AdminAccessDeniedException;
        }

        $session['mfa_factor_ids'] = array_column($factors, 'id');
        $session['mfa_challenge_id'] = null;
        $session['mfa_challenge_factor_id'] = null;
        $request->session()->regenerate(true);
        $this->write($request, self::PENDING_KEY, $session);

        return $factors;
    }

    /**
     * @param  array<string, mixed>  $factor
     * @param  array<string, mixed>  $challenge
     */
    public function beginMfaEnrollment(
        Request $request,
        array $session,
        array $factor,
        array $challenge,
    ): void {
        $session = $this->auth->assertAdminSession($session);
        if (
            ! $this->auth->requiresMfaEnrollment($session['user'])
            || ! is_string($factor['id'] ?? null)
            || ! is_string($challenge['id'] ?? null)
            || ! is_array($factor['totp'] ?? null)
            || ! is_string($factor['totp']['secret'] ?? null)
            || ! is_string($factor['totp']['uri'] ?? null)
            || ! is_string($factor['totp']['qr_code'] ?? null)
        ) {
            throw new AdminAccessDeniedException;
        }

        $session['mfa_factor_id'] = $factor['id'];
        $session['mfa_challenge_id'] = $challenge['id'];
        $session['mfa_enrollment_secret'] = $factor['totp']['secret'];
        $session['mfa_enrollment_uri'] = $factor['totp']['uri'];
        $session['mfa_enrollment_qr_code'] = $factor['totp']['qr_code'];
        $session['mfa_enrollment_expires_at'] = now()->addMinutes(10)->timestamp;

        $request->session()->regenerate(true);
        $this->write($request, self::PENDING_ENROLLMENT_KEY, $session);
        $request->session()->forget(self::PENDING_KEY);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function pendingMfaEnrollment(Request $request): ?array
    {
        $session = $this->read($request, self::PENDING_ENROLLMENT_KEY);
        if ($session === null) {
            return null;
        }

        $expiresAt = is_numeric($session['mfa_enrollment_expires_at'] ?? null)
            ? (int) $session['mfa_enrollment_expires_at']
            : 0;
        if ($expiresAt < now()->timestamp) {
            $request->session()->forget(self::PENDING_ENROLLMENT_KEY);

            return null;
        }

        return $session;
    }

    /**
     * @param  array<string, mixed>  $challenge
     */
    public function beginReauthentication(
        Request $request,
        string $factorId,
        array $challenge,
    ): void {
        $session = $this->read($request, self::SESSION_KEY);
        $factorIds = is_array($session['user'] ?? null)
            ? array_column($this->auth->verifiedFactors($session['user']), 'id')
            : [];
        if (
            $session === null
            || ! in_array($factorId, $factorIds, true)
            || ! is_string($challenge['id'] ?? null)
        ) {
            throw new AdminAccessDeniedException;
        }

        $session['reauth_factor_id'] = $factorId;
        $session['reauth_challenge_id'] = $challenge['id'];
        $session['reauth_expires_at'] = now()->addMinutes(5)->timestamp;
        $request->session()->regenerate(true);
        $this->write($request, self::PENDING_REAUTH_KEY, $session);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function pendingReauthentication(Request $request): ?array
    {
        $session = $this->read($request, self::PENDING_REAUTH_KEY);
        if ($session === null) {
            return null;
        }

        $expiresAt = is_numeric($session['reauth_expires_at'] ?? null)
            ? (int) $session['reauth_expires_at']
            : 0;
        if ($expiresAt < now()->timestamp) {
            $request->session()->forget(self::PENDING_REAUTH_KEY);

            return null;
        }

        return $session;
    }

    /**
     * @return array<int, array{id: string, factor_type: string, friendly_name: string|null}>
     */
    public function verifiedFactorsForCurrentSession(Request $request): array
    {
        $session = $this->read($request, self::SESSION_KEY);

        return is_array($session['user'] ?? null)
            ? $this->auth->verifiedFactors($session['user'])
            : [];
    }

    public function reauthenticationIsRecent(Request $request): bool
    {
        $session = $this->read($request, self::SESSION_KEY);
        $verifiedAt = is_numeric($session['mfa_verified_at'] ?? null)
            ? (int) $session['mfa_verified_at']
            : 0;

        return $verifiedAt <= now()->timestamp
            && $verifiedAt >= now()->subMinutes(5)->timestamp;
    }

    /**
     * @param  array<string, mixed>  $session
     */
    public function completeReauthentication(Request $request, array $session): AdminIdentity
    {
        $pending = $this->pendingReauthentication($request);
        $active = $this->read($request, self::SESSION_KEY);
        if (
            $pending === null
            || ! is_array($active['user'] ?? null)
            || ! is_array($session['user'] ?? null)
            || ($active['user']['id'] ?? null) !== ($pending['user']['id'] ?? null)
            || ($session['user']['id'] ?? null) !== ($active['user']['id'] ?? null)
            || ! is_string($session['access_token'] ?? null)
            || ! $this->auth->mfaIsSatisfied($session['user'], $session['access_token'])
        ) {
            throw new AdminAccessDeniedException;
        }

        $identity = $this->store($request, $session);
        $request->session()->forget(self::PENDING_REAUTH_KEY);

        return $identity;
    }

    /**
     * @param  array<string, mixed>  $challenge
     */
    public function setMfaChallenge(
        Request $request,
        string $factorId,
        array $challenge,
    ): void {
        $session = $this->read($request, self::PENDING_KEY);
        if (
            $session === null
            || ! in_array($factorId, $session['mfa_factor_ids'] ?? [], true)
            || ! is_string($challenge['id'] ?? null)
        ) {
            throw new AdminAccessDeniedException;
        }

        $session['mfa_challenge_id'] = $challenge['id'];
        $session['mfa_challenge_factor_id'] = $factorId;
        $this->write($request, self::PENDING_KEY, $session);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function pendingMfa(Request $request): ?array
    {
        return $this->read($request, self::PENDING_KEY);
    }

    public function completeMfa(Request $request, array $session): AdminIdentity
    {
        $session = $this->auth->assertAdminSession($session);
        $user = $session['user'];

        if ($this->auth->requiresMfa($user, $session['access_token'])) {
            throw new AdminMfaRequiredException;
        }

        $request->session()->forget(self::PENDING_KEY);

        return $this->store($request, $session);
    }

    public function current(Request $request): ?AdminIdentity
    {
        $session = $this->read($request, self::SESSION_KEY);
        if ($session === null) {
            return null;
        }

        if (
            ! is_string($session['access_token'] ?? null)
            || ! is_string($session['refresh_token'] ?? null)
            || ! is_array($session['user'] ?? null)
            || ! is_string($session['user']['id'] ?? null)
        ) {
            $this->forget($request);

            return null;
        }

        $storedUserId = $session['user']['id'];
        $expiresAt = is_numeric($session['expires_at'] ?? null)
            ? (int) $session['expires_at']
            : 0;

        try {
            if ($expiresAt <= now()->timestamp + 60) {
                $session = $this->auth->refresh($session['refresh_token']);
            } else {
                try {
                    $session['user'] = $this->auth->user($session['access_token']);
                } catch (SupabaseRequestException $exception) {
                    if ($exception->status !== 401) {
                        throw $exception;
                    }

                    $session = $this->auth->refresh($session['refresh_token']);
                }
            }
        } catch (SupabaseRequestException $exception) {
            if (in_array($exception->status, [400, 401, 403], true)) {
                $this->forget($request);

                return null;
            }

            throw $exception;
        }

        $user = $session['user'] ?? null;
        if (
            ! is_array($user)
            || ! is_string($user['id'] ?? null)
            || ! is_string($user['email'] ?? null)
            || $user['id'] !== $storedUserId
        ) {
            $this->forget($request);

            return null;
        }

        if ($this->auth->role($user) === null) {
            $this->forget($request);

            return null;
        }

        $directoryUser = $this->repository->user($user['id']);
        if (
            $directoryUser === null
            || ! is_string($directoryUser['email'] ?? null)
            || ($directoryUser['is_suspended'] ?? true) === true
            || ($directoryUser['admin_role'] ?? null) !== ($user['app_metadata']['role'] ?? null)
            || mb_strtolower($directoryUser['email'] ?? '') !== mb_strtolower($user['email'])
        ) {
            $this->forget($request);

            return null;
        }

        if (
            $this->auth->requiresMfaEnrollment($user)
            || $this->auth->requiresMfa($user, $session['access_token'])
        ) {
            $this->forget($request);

            throw new AdminMfaRequiredException;
        }

        $session = $this->auth->assertAdminSession($session);
        $this->write($request, self::SESSION_KEY, $session);

        return $this->identity($user);
    }

    public function accessToken(Request $request): ?string
    {
        $session = $this->read($request, self::SESSION_KEY);

        return is_string($session['access_token'] ?? null)
            ? $session['access_token']
            : null;
    }

    public function forget(Request $request): void
    {
        $request->session()->forget([
            self::SESSION_KEY,
            self::PENDING_KEY,
            self::PENDING_ENROLLMENT_KEY,
            self::PENDING_REAUTH_KEY,
        ]);
    }

    private function identity(array $user): AdminIdentity
    {
        $role = $this->auth->role($user);
        if ($role === null || ! is_string($user['id'] ?? null) || ! is_string($user['email'] ?? null)) {
            throw new AdminAccessDeniedException;
        }

        return new AdminIdentity($user['id'], $user['email'], $role);
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function write(Request $request, string $key, array $payload): void
    {
        $request->session()->put(
            $key,
            Crypt::encryptString(json_encode($payload, JSON_THROW_ON_ERROR)),
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    private function read(Request $request, string $key): ?array
    {
        $encrypted = $request->session()->get($key);
        if (! is_string($encrypted)) {
            return null;
        }

        try {
            $payload = json_decode(Crypt::decryptString($encrypted), true, 512, JSON_THROW_ON_ERROR);
        } catch (DecryptException|JsonException) {
            $request->session()->forget($key);
            Log::warning('An invalid Super Admin session payload was discarded.');

            return null;
        }

        return is_array($payload) ? $payload : null;
    }
}
