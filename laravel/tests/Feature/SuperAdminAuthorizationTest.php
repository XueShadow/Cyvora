<?php

namespace Tests\Feature;

use Illuminate\Http\Client\Request as ClientRequest;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SuperAdminAuthorizationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('b', 32)),
            'services.supabase.url' => 'https://cyvora.test',
            'services.supabase.anon_key' => 'anon-test-key',
            'services.supabase.service_role_key' => 'service-role-test-key',
            'services.supabase.timeout' => 2,
            'services.supabase.connect_timeout' => 1,
        ]);
    }

    public function test_admin_routes_require_an_authenticated_admin_session(): void
    {
        Http::fake(['*' => Http::response([], 201)]);

        $this->get('/admin/users')->assertRedirect(route('admin.login'));
    }

    public function test_moderator_cannot_access_user_management(): void
    {
        $this->fakeAuth('moderator');
        $this->signIn(route('admin.intelligence.index'));

        $this->get('/admin/users')->assertForbidden();

        Http::assertSent(fn (ClientRequest $request): bool => str_contains($request->url(), '/rest/v1/admin_audit_logs')
            && ($request->data()['action'] ?? null) === 'admin.permission.denied'
            && ($request->data()['outcome'] ?? null) === 'denied');
    }

    public function test_support_admin_cannot_access_scan_history(): void
    {
        $this->fakeAuth('support_admin');
        $this->signIn(route('admin.dashboard'));

        $this->get('/admin/scans')->assertForbidden();
    }

    public function test_admin_cannot_assign_administrator_roles(): void
    {
        $this->fakeAuth('admin');
        $this->signIn(route('admin.dashboard'));

        $this->post('/admin/admins/role', [
            'email' => 'new-admin@example.test',
            'role' => 'super_admin',
            'email_confirmation' => 'new-admin@example.test',
        ])->assertForbidden();

        Http::assertNotSent(
            fn (ClientRequest $request): bool => str_contains($request->url(), '/auth/v1/admin/users/'),
        );
    }

    public function test_server_role_change_revokes_an_existing_panel_session(): void
    {
        $this->fakeAuth('admin', 'moderator');
        $this->signIn(route('admin.dashboard'));

        $this->get('/admin/users')->assertRedirect(route('admin.login'));
    }

    public function test_suspended_account_cannot_reuse_an_existing_panel_session(): void
    {
        $this->fakeAuth('admin', 'admin', true);
        $this->signIn(route('admin.dashboard'));

        $this->get('/admin/users')->assertRedirect(route('admin.login'));
    }

    public function test_deletion_target_cannot_review_or_execute_own_deletion(): void
    {
        $user = [
            'id' => '550e8400-e29b-41d4-a716-446655440000',
            'email' => 'admin@example.test',
            'email_confirmed_at' => '2026-01-01T00:00:00Z',
            'app_metadata' => ['role' => 'super_admin'],
            'factors' => [],
        ];
        $session = [
            'access_token' => 'header.access-token.signature',
            'refresh_token' => 'refresh-token',
            'expires_in' => 3600,
            'user' => $user,
        ];
        $deletionRequest = [
            'id' => '550e8400-e29b-41d4-a716-446655440001',
            'target_user_id' => $user['id'],
            'requester_id' => '550e8400-e29b-41d4-a716-446655440002',
            'requester_role' => 'admin',
            'reason' => 'Requested by a verified administrator.',
            'status' => 'pending',
            'reviewed_by' => null,
            'reviewed_at' => null,
            'created_at' => '2026-01-01T00:00:00Z',
        ];

        Http::fake(function (ClientRequest $request) use ($session, $user, &$deletionRequest) {
            if (str_contains($request->url(), '/auth/v1/token')) {
                return Http::response($session, 200);
            }
            if (str_contains($request->url(), '/auth/v1/user')) {
                return Http::response($user, 200);
            }
            if (str_contains($request->url(), '/rest/v1/admin_user_directory')) {
                return Http::response([[
                    'id' => $user['id'],
                    'email' => $user['email'],
                    'admin_role' => 'super_admin',
                    'is_suspended' => false,
                ]], 200, ['Content-Range' => '0-0/1']);
            }
            if (str_contains($request->url(), '/rest/v1/admin_account_deletion_requests')) {
                return Http::response([$deletionRequest], 200, ['Content-Range' => '0-0/1']);
            }
            if (str_contains($request->url(), '/rest/v1/admin_audit_logs')) {
                return Http::response([], 201);
            }

            return Http::response([], 200);
        });

        $this->signIn(route('admin.dashboard'));
        $this->post('/admin/deletion-requests/'.$deletionRequest['id'].'/review', [
            'decision' => 'approved',
            'confirmation' => 'APPROVE',
        ])->assertStatus(409);

        $deletionRequest['status'] = 'approved';
        $deletionRequest['reviewed_by'] = '550e8400-e29b-41d4-a716-446655440003';
        $this->post('/admin/deletion-requests/'.$deletionRequest['id'].'/execute', [
            'email_confirmation' => $user['email'],
            'confirmation' => 'DELETE ACCOUNT',
        ])->assertStatus(409);

        Http::assertNotSent(
            fn (ClientRequest $request): bool => str_contains($request->url(), '/auth/v1/admin/users/')
                && $request->method() === 'DELETE',
        );
    }

    public function test_account_suspension_requires_confirmation_fields(): void
    {
        $this->fakeAuth('admin');
        $this->signIn(route('admin.dashboard'));

        $this->post('/admin/users/550e8400-e29b-41d4-a716-446655440001/suspend', [])
            ->assertSessionHasErrors(['email_confirmation', 'ban_duration']);

        Http::assertNotSent(
            fn (ClientRequest $request): bool => str_contains($request->url(), '/auth/v1/admin/users/'),
        );
    }

    public function test_admin_mutation_routes_remain_in_the_web_middleware_group(): void
    {
        $route = app('router')->getRoutes()->getByName('admin.users.suspend');

        $this->assertNotNull($route);
        $this->assertContains('web', $route->gatherMiddleware());
    }

    private function signIn(string $landingRoute): void
    {
        $this->post('/admin/login', [
            'email' => 'admin@example.test',
            'password' => 'correct horse battery staple',
        ])->assertRedirect($landingRoute);
    }

    private function fakeAuth(
        string $role,
        ?string $directoryRole = null,
        bool $isSuspended = false,
    ): void {
        $directoryRole ??= $role;
        $user = [
            'id' => '550e8400-e29b-41d4-a716-446655440000',
            'email' => 'admin@example.test',
            'email_confirmed_at' => '2026-01-01T00:00:00Z',
            'app_metadata' => ['role' => $role],
            'factors' => [],
        ];
        $session = [
            'access_token' => 'header.access-token.signature',
            'refresh_token' => 'refresh-token',
            'expires_in' => 3600,
            'user' => $user,
        ];

        Http::fake(function (ClientRequest $request) use ($session, $user, $directoryRole, $isSuspended) {
            if (str_contains($request->url(), '/auth/v1/token')) {
                return Http::response($session, 200);
            }
            if (str_contains($request->url(), '/auth/v1/user')) {
                return Http::response($user, 200);
            }
            if (str_contains($request->url(), '/rest/v1/admin_user_directory')) {
                return Http::response([[
                    'id' => $user['id'],
                    'email' => $user['email'],
                    'admin_role' => $directoryRole,
                    'is_suspended' => $isSuspended,
                ]], 200, ['Content-Range' => '0-0/1']);
            }
            if (str_contains($request->url(), '/rest/v1/admin_audit_logs')) {
                return Http::response([], 201);
            }

            return Http::response([], 200);
        });
    }
}
