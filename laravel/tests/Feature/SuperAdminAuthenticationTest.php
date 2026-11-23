<?php

namespace Tests\Feature;

use Illuminate\Http\Client\Request as ClientRequest;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SuperAdminAuthenticationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->configureSupabase();
    }

    public function test_admin_sign_in_uses_server_assigned_role_and_encrypts_session_tokens(): void
    {
        Http::fake([
            'https://cyvora.test/auth/v1/token*' => Http::response($this->authResponse('super_admin')),
            'https://cyvora.test/rest/v1/admin_audit_logs*' => Http::response([], 201),
        ]);

        $response = $this->post('/admin/login', [
            'email' => 'admin@example.test',
            'password' => 'correct horse battery staple',
        ]);

        $response->assertRedirect(route('admin.dashboard'));
        $storedSession = session('admin.auth');
        $this->assertIsString($storedSession);
        $this->assertStringNotContainsString('secret-access-token', $storedSession);
        $this->assertStringNotContainsString('secret-refresh-token', $storedSession);
        Http::assertSent(fn ($request): bool => str_contains($request->url(), '/auth/v1/token')
            && $request->hasHeader('apikey', 'anon-test-key'));
    }

    public function test_logout_revokes_the_supabase_session_and_clears_the_panel_session(): void
    {
        $this->fakeAdminSessionAuth();
        $this->signIn();

        $this->post('/admin/logout')
            ->assertRedirect(route('admin.login'))
            ->assertSessionHas('status', 'You have signed out.');

        $this->assertNull(session('admin.auth'));
        Http::assertSent(fn (ClientRequest $request): bool => str_contains($request->url(), '/auth/v1/logout')
            && str_contains($request->url(), 'scope=local')
            && $request->hasHeader('Authorization', 'Bearer header.secret-access-token.signature'));
    }

    public function test_local_logout_completes_when_supabase_cannot_confirm_revocation(): void
    {
        $this->fakeAdminSessionAuth(503);
        $this->signIn();

        $this->post('/admin/logout')
            ->assertRedirect(route('admin.login'))
            ->assertSessionHas('status', 'Your local panel session was cleared, but Supabase did not confirm sign-out.');

        $this->assertNull(session('admin.auth'));
    }

    public function test_verified_mfa_factor_is_required_before_creating_an_admin_session(): void
    {
        $user = $this->authResponse('super_admin')['user'];
        $user['factors'] = [[
            'id' => 'factor-123',
            'factor_type' => 'totp',
            'status' => 'verified',
        ]];
        $pendingSession = [
            'access_token' => $this->tokenWithAal('aal1'),
            'refresh_token' => 'pending-refresh-token',
            'expires_in' => 3600,
            'user' => $user,
        ];
        $verifiedSession = [
            'access_token' => $this->tokenWithAal('aal2'),
            'refresh_token' => 'verified-refresh-token',
            'expires_in' => 3600,
            'user' => $user,
        ];

        Http::fake(function (ClientRequest $request) use ($pendingSession, $verifiedSession) {
            if (str_contains($request->url(), '/auth/v1/token')) {
                return Http::response($pendingSession, 200);
            }
            if (str_contains($request->url(), '/auth/v1/factors/factor-123/challenge')) {
                return Http::response(['id' => 'challenge-123'], 200);
            }
            if (str_contains($request->url(), '/auth/v1/factors/factor-123/verify')) {
                return Http::response($verifiedSession, 200);
            }
            if (str_contains($request->url(), '/rest/v1/admin_audit_logs')) {
                return Http::response([], 201);
            }

            return Http::response([], 200);
        });

        $this->post('/admin/login', [
            'email' => 'admin@example.test',
            'password' => 'correct horse battery staple',
        ])->assertRedirect(route('admin.mfa.show'));

        $this->assertNull(session('admin.auth'));
        $this->post('/admin/mfa', ['code' => '123456'])
            ->assertRedirect(route('admin.dashboard'));

        $this->assertIsString(session('admin.auth'));
        $this->assertStringNotContainsString('verified-refresh-token', session('admin.auth'));
        $this->assertNull(session('admin.pending_auth'));
    }

    public function test_mfa_verification_without_an_aal2_token_is_rejected(): void
    {
        $user = $this->authResponse('super_admin')['user'];
        $user['factors'] = [[
            'id' => 'factor-123',
            'factor_type' => 'totp',
            'status' => 'verified',
        ]];
        $pendingSession = [
            'access_token' => $this->tokenWithAal('aal1'),
            'refresh_token' => 'pending-refresh-token',
            'expires_in' => 3600,
            'user' => $user,
        ];
        $unverifiedSession = $pendingSession;

        Http::fake(function (ClientRequest $request) use ($pendingSession, $unverifiedSession) {
            if (str_contains($request->url(), '/auth/v1/token')) {
                return Http::response($pendingSession, 200);
            }
            if (str_contains($request->url(), '/auth/v1/factors/factor-123/challenge')) {
                return Http::response(['id' => 'challenge-123'], 200);
            }
            if (str_contains($request->url(), '/auth/v1/factors/factor-123/verify')) {
                return Http::response($unverifiedSession, 200);
            }
            if (str_contains($request->url(), '/rest/v1/admin_audit_logs')) {
                return Http::response([], 201);
            }

            return Http::response([], 200);
        });

        $this->post('/admin/login', [
            'email' => 'admin@example.test',
            'password' => 'correct horse battery staple',
        ])->assertRedirect(route('admin.mfa.show'));

        $this->from('/admin/mfa')->post('/admin/mfa', ['code' => '123456'])
            ->assertRedirect('/admin/mfa')
            ->assertSessionHasErrors('code');

        $this->assertNull(session('admin.auth'));
    }

    public function test_user_metadata_cannot_grant_admin_access(): void
    {
        $response = $this->authResponse(null);
        $response['user']['user_metadata'] = ['role' => 'super_admin'];

        Http::fake([
            'https://cyvora.test/auth/v1/token*' => Http::response($response),
            'https://cyvora.test/rest/v1/admin_audit_logs*' => Http::response([], 201),
        ]);

        $this->from('/admin/login')
            ->post('/admin/login', [
                'email' => 'user@example.test',
                'password' => 'correct horse battery staple',
            ])
            ->assertRedirect('/admin/login')
            ->assertSessionHasErrors('email');

        $this->assertNull(session('admin.auth'));
    }

    public function test_public_registration_route_does_not_exist(): void
    {
        $this->get('/admin/register')->assertNotFound();
    }

    public function test_admin_sign_in_is_rate_limited(): void
    {
        Http::fake([
            'https://cyvora.test/auth/v1/token*' => Http::response(['msg' => 'Invalid credentials'], 401),
            'https://cyvora.test/rest/v1/admin_audit_logs*' => Http::response([], 201),
        ]);

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->from('/admin/login')->post('/admin/login', [
                'email' => 'admin@example.test',
                'password' => 'incorrect password',
            ])->assertRedirect('/admin/login');
        }

        $this->from('/admin/login')->post('/admin/login', [
            'email' => 'admin@example.test',
            'password' => 'incorrect password',
        ])->assertTooManyRequests();
    }

    public function test_password_recovery_uses_generic_response_for_unknown_accounts(): void
    {
        Http::fake([
            'https://cyvora.test/auth/v1/recover*' => Http::response([], 200),
        ]);
        config(['services.supabase.admin_password_reset_redirect' => 'https://admin.cyvora.example/admin/password/reset']);

        $this->post('/admin/forgot-password', ['email' => 'unknown@example.test'])
            ->assertRedirect()
            ->assertSessionHas('status', 'If an authorized account exists, password recovery instructions have been sent.');
    }

    /**
     * @return array<string, mixed>
     */
    private function authResponse(?string $role): array
    {
        return [
            'access_token' => 'header.secret-access-token.signature',
            'refresh_token' => 'secret-refresh-token',
            'expires_in' => 3600,
            'user' => [
                'id' => '550e8400-e29b-41d4-a716-446655440000',
                'email' => $role === null ? 'user@example.test' : 'admin@example.test',
                'email_confirmed_at' => '2026-01-01T00:00:00Z',
                'app_metadata' => $role === null ? [] : ['role' => $role],
                'factors' => [],
            ],
        ];
    }

    private function configureSupabase(): void
    {
        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('a', 32)),
            'services.supabase.url' => 'https://cyvora.test',
            'services.supabase.anon_key' => 'anon-test-key',
            'services.supabase.service_role_key' => 'service-role-test-key',
            'services.supabase.timeout' => 2,
            'services.supabase.connect_timeout' => 1,
        ]);
    }

    private function signIn(): void
    {
        $this->post('/admin/login', [
            'email' => 'admin@example.test',
            'password' => 'correct horse battery staple',
        ])->assertRedirect(route('admin.dashboard'));
    }

    private function fakeAdminSessionAuth(int $logoutStatus = 204): void
    {
        $session = $this->authResponse('super_admin');
        $user = $session['user'];

        Http::fake(function (ClientRequest $request) use ($session, $user, $logoutStatus) {
            if (str_contains($request->url(), '/auth/v1/token')) {
                return Http::response($session, 200);
            }
            if (str_contains($request->url(), '/auth/v1/user')) {
                return Http::response($user, 200);
            }
            if (str_contains($request->url(), '/auth/v1/logout')) {
                return Http::response([], $logoutStatus);
            }
            if (str_contains($request->url(), '/rest/v1/admin_user_directory')) {
                return Http::response([[
                    'id' => $user['id'],
                    'email' => $user['email'],
                    'admin_role' => 'super_admin',
                    'is_suspended' => false,
                ]], 200, ['Content-Range' => '0-0/1']);
            }
            if (str_contains($request->url(), '/rest/v1/admin_audit_logs')) {
                return Http::response([], 201);
            }

            return Http::response([], 200);
        });
    }

    private function tokenWithAal(string $aal): string
    {
        $payload = rtrim(strtr(base64_encode(json_encode(['aal' => $aal], JSON_THROW_ON_ERROR)), '+/', '-_'), '=');

        return 'header.'.$payload.'.signature';
    }
}
