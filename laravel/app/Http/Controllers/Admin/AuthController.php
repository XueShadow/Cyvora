<?php

namespace App\Http\Controllers\Admin;

use App\Admin\AdminIdentity;
use App\Admin\AdminSession;
use App\Exceptions\AdminAccessDeniedException;
use App\Exceptions\SupabaseConfigurationException;
use App\Exceptions\SupabaseRequestException;
use App\Exceptions\SupabaseUnavailableException;
use App\Http\Controllers\Controller;
use App\Services\AdminAuditLogger;
use App\Services\SupabaseAdminAuth;
use App\Services\SupabaseAdminClient;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AuthController extends Controller
{
    public function showLogin(): View
    {
        return view('admin.auth.login');
    }

    public function login(
        Request $request,
        SupabaseAdminAuth $auth,
        AdminSession $adminSession,
        AdminAuditLogger $audit,
    ): RedirectResponse|View {
        $credentials = $request->validate([
            'email' => ['required', 'email', 'max:254'],
            'password' => ['required', 'string', 'max:1024'],
        ]);

        try {
            $session = $auth->signIn($credentials['email'], $credentials['password']);
        } catch (AdminAccessDeniedException|SupabaseRequestException $exception) {
            if (
                $exception instanceof SupabaseRequestException
                && ! in_array($exception->status, [400, 401, 403], true)
            ) {
                throw $exception;
            }

            $audit->record(
                $request,
                null,
                'admin.login',
                'admin_account',
                null,
                'denied',
                ['source_ip_hash' => hash_hmac('sha256', (string) $request->ip(), (string) config('app.key'))],
            );

            return back()
                ->withInput($request->only('email'))
                ->withErrors(['email' => 'The sign-in details are invalid or the account is not authorized.']);
        } catch (SupabaseConfigurationException|SupabaseUnavailableException) {
            return response()->view('admin.errors.unavailable', [
                'message' => 'Admin sign-in is unavailable. Check the server-side Supabase configuration and connectivity.',
            ], 503);
        }

        $user = $session['user'];

        if ($auth->requiresMfa($user, $session['access_token'])) {
            try {
                $factors = $adminSession->beginMfa($request, $session);
                $factor = $factors[0];
                $challenge = $auth->challenge($session['access_token'], $factor['id']);
                $adminSession->setMfaChallenge($request, $factor['id'], $challenge);
            } catch (SupabaseRequestException $exception) {
                $adminSession->forget($request);
                if (! in_array($exception->status, [400, 401, 403, 429], true)) {
                    throw $exception;
                }

                $audit->record($request, null, 'admin.login.mfa', 'admin_account', null, 'denied');

                return back()->withErrors(['email' => 'The multi-factor challenge could not be started. Try signing in again.']);
            }

            return redirect()->route('admin.mfa.show');
        }

        $role = $auth->role($user);
        if ($role === null) {
            throw new AdminAccessDeniedException;
        }

        $identity = new AdminIdentity($user['id'], $user['email'], $role);
        $audit->record($request, $identity, 'admin.login', 'admin_account', $identity->id, 'started');
        $adminSession->store($request, $session);
        $audit->record(
            $request,
            $identity,
            'admin.login',
            'admin_account',
            $identity->id,
            'succeeded',
        );

        return redirect()->intended($this->landingRoute($identity));
    }

    public function showMfa(Request $request, AdminSession $adminSession): View|RedirectResponse
    {
        $pending = $adminSession->pendingMfa($request);
        if (
            $pending === null
            || ! is_string($pending['mfa_challenge_id'] ?? null)
            || ! is_string($pending['mfa_challenge_factor_id'] ?? null)
        ) {
            return redirect()->route('admin.login');
        }

        $factor = collect($pending['user']['factors'] ?? [])
            ->firstWhere('id', $pending['mfa_challenge_factor_id']);

        return view('admin.auth.mfa', [
            'factorType' => is_array($factor) ? ($factor['factor_type'] ?? 'factor') : 'factor',
        ]);
    }

    public function verifyMfa(
        Request $request,
        SupabaseAdminAuth $auth,
        AdminSession $adminSession,
        AdminAuditLogger $audit,
    ): RedirectResponse|View {
        $request->validate(['code' => ['required', 'digits:6']]);
        $pending = $adminSession->pendingMfa($request);

        if (
            $pending === null
            || ! is_string($pending['access_token'] ?? null)
            || ! is_string($pending['mfa_challenge_id'] ?? null)
            || ! is_string($pending['mfa_challenge_factor_id'] ?? null)
        ) {
            return redirect()->route('admin.login');
        }

        try {
            $session = $auth->verifyChallenge(
                $pending['access_token'],
                $pending['mfa_challenge_factor_id'],
                $pending['mfa_challenge_id'],
                $request->string('code')->toString(),
            );
        } catch (AdminAccessDeniedException|SupabaseRequestException $exception) {
            if (
                $exception instanceof SupabaseRequestException
                && ! in_array($exception->status, [400, 401, 403], true)
            ) {
                throw $exception;
            }

            $audit->record(
                $request,
                null,
                'admin.login.mfa',
                'admin_account',
                null,
                'denied',
            );

            return back()->withErrors(['code' => 'The verification code was rejected. Request a new sign-in challenge.']);
        } catch (SupabaseConfigurationException|SupabaseUnavailableException) {
            return response()->view('admin.errors.unavailable', [
                'message' => 'Multi-factor verification is temporarily unavailable.',
            ], 503);
        }

        $user = $session['user'];
        $role = $auth->role($user);
        if ($role === null) {
            throw new AdminAccessDeniedException;
        }
        $identity = new AdminIdentity($user['id'], $user['email'], $role);
        $audit->record($request, $identity, 'admin.login', 'admin_account', $identity->id, 'started', [
            'mfa' => 'verified',
        ]);
        $adminSession->completeMfa($request, $session);
        $audit->record($request, $identity, 'admin.login', 'admin_account', $identity->id, 'succeeded', [
            'mfa' => 'verified',
        ]);

        return redirect()->intended($this->landingRoute($identity));
    }

    public function logout(
        Request $request,
        AdminSession $adminSession,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $identity = $request->attributes->get('admin');
        $token = $adminSession->accessToken($request);
        $revoked = $token === null;
        $failureStatus = null;

        if ($token !== null) {
            try {
                $client->signOut($token);
                $revoked = true;
            } catch (SupabaseRequestException $exception) {
                $revoked = $exception->status === 401;
                $failureStatus = $exception->status;
            } catch (SupabaseConfigurationException|SupabaseUnavailableException) {
                $revoked = false;
            }
        }

        $adminSession->forget($request);
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        $audit->record(
            $request,
            $identity,
            'admin.logout',
            'admin_account',
            $identity->id,
            $revoked ? 'succeeded' : 'failed',
            ['local_session_cleared' => true, 'http_status' => $failureStatus],
        );

        $response = redirect()->route('admin.login');

        return $revoked
            ? $response->with('status', 'You have signed out.')
            : $response->with('status', 'Your local panel session was cleared, but Supabase did not confirm sign-out.');
    }

    public function showForgotPassword(): View
    {
        return view('admin.auth.forgot-password');
    }

    public function sendPasswordReset(
        Request $request,
        SupabaseAdminClient $client,
    ): RedirectResponse|View {
        $credentials = $request->validate(['email' => ['required', 'email', 'max:254']]);
        $redirectTo = config('services.supabase.admin_password_reset_redirect');

        if (! is_string($redirectTo) || ! str_starts_with($redirectTo, 'https://')) {
            return response()->view('admin.errors.unavailable', [
                'message' => 'Password recovery is not configured with an HTTPS callback URL.',
            ], 503);
        }

        try {
            $client->requestPasswordReset($credentials['email'], $redirectTo);
        } catch (SupabaseRequestException $exception) {
            if (! in_array($exception->status, [400, 429], true)) {
                throw $exception;
            }
        } catch (SupabaseConfigurationException|SupabaseUnavailableException) {
            return response()->view('admin.errors.unavailable', [
                'message' => 'Password recovery is temporarily unavailable.',
            ], 503);
        }

        return back()->with('status', 'If an authorized account exists, password recovery instructions have been sent.');
    }

    public function showResetPassword(): View
    {
        return view('admin.auth.reset-password');
    }

    public function resetPassword(
        Request $request,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse|View {
        $data = $request->validate([
            'access_token' => ['required', 'string', 'min:20', 'max:4096'],
            'password' => ['required', 'string', 'min:12', 'max:128', 'confirmed'],
        ]);

        try {
            $client->updatePassword($data['access_token'], $data['password']);
            $audit->record(
                $request,
                null,
                'admin.password_reset',
                'admin_account',
                null,
                'succeeded',
            );
        } catch (SupabaseRequestException $exception) {
            if (! in_array($exception->status, [400, 401, 403], true)) {
                throw $exception;
            }

            return back()->withErrors(['access_token' => 'The recovery link is invalid or expired.']);
        } catch (SupabaseConfigurationException|SupabaseUnavailableException) {
            return response()->view('admin.errors.unavailable', [
                'message' => 'Password reset is temporarily unavailable.',
            ], 503);
        }

        return redirect()
            ->route('admin.login')
            ->with('status', 'Password updated. Sign in with your new password.');
    }

    private function landingRoute(AdminIdentity $identity): string
    {
        if ($identity->can('dashboard.view')) {
            return route('admin.dashboard');
        }

        if ($identity->can('intelligence.view')) {
            return route('admin.intelligence.index');
        }

        if ($identity->can('users.view')) {
            return route('admin.users.index');
        }

        throw new AdminAccessDeniedException;
    }
}
