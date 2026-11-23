<?php

namespace Tests\Feature;

use App\Admin\AdminIdentity;
use App\Admin\AdminRole;
use App\Exceptions\SupabaseConfigurationException;
use App\Services\AdminAuditLogger;
use App\Services\SupabaseAdminClient;
use App\Services\SupabaseAdminRepository;
use Illuminate\Http\Client\Request as ClientRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SupabaseAdminIntegrationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('c', 32)),
            'services.supabase.url' => 'https://cyvora.test',
            'services.supabase.anon_key' => 'anon-test-key',
            'services.supabase.service_role_key' => 'service-role-test-key',
            'services.supabase.timeout' => 2,
            'services.supabase.connect_timeout' => 1,
        ]);
    }

    public function test_browser_responses_never_expose_supabase_server_credentials(): void
    {
        $this->get('/admin/login')
            ->assertOk()
            ->assertDontSee('service-role-test-key')
            ->assertDontSee('anon-test-key');
    }

    public function test_existing_edge_function_receives_admin_user_token_not_service_role_key(): void
    {
        Http::fake([
            'https://cyvora.test/functions/v1/scam-intelligence' => Http::response(['submissions' => []]),
        ]);

        app(SupabaseAdminClient::class)->callFunction(
            'scam-intelligence',
            ['action' => 'review_queue', 'limit' => 30],
            'admin-user-access-token',
        );

        Http::assertSent(fn (ClientRequest $request): bool => str_contains($request->url(), '/functions/v1/scam-intelligence')
            && $request->hasHeader('apikey', 'anon-test-key')
            && $request->hasHeader('Authorization', 'Bearer admin-user-access-token')
            && ! str_contains($request->body(), 'service-role-test-key'));
    }

    public function test_auth_admin_operations_use_service_credentials_only_server_side(): void
    {
        Http::fake([
            'https://cyvora.test/auth/v1/admin/users/*' => Http::response(['id' => '550e8400-e29b-41d4-a716-446655440000']),
        ]);

        app(SupabaseAdminClient::class)->updateAuthUser(
            '550e8400-e29b-41d4-a716-446655440000',
            ['ban_duration' => '24h'],
        );

        Http::assertSent(fn (ClientRequest $request): bool => str_contains($request->url(), '/auth/v1/admin/users/')
            && $request->hasHeader('apikey', 'service-role-test-key')
            && $request->hasHeader('Authorization', 'Bearer service-role-test-key'));
    }

    public function test_production_supabase_requests_require_tls(): void
    {
        config([
            'app.env' => 'production',
            'services.supabase.url' => 'http://cyvora.test',
        ]);
        Http::fake();

        $this->expectException(SupabaseConfigurationException::class);

        app(SupabaseAdminClient::class)->currentUser('admin-user-access-token');
    }

    public function test_dashboard_reads_the_full_selected_daily_series_from_supabase(): void
    {
        $daily = [];
        for ($offset = 89; $offset >= 0; $offset--) {
            $daily[] = [
                'day' => now()->subDays($offset)->toDateString(),
                'registration_count' => 1,
                'scan_count' => 2,
                'low_risk_count' => 1,
                'review_risk_count' => 0,
                'high_risk_count' => 1,
            ];
        }

        Http::fake(function (ClientRequest $request) use ($daily) {
            if (str_contains($request->url(), '/rest/v1/admin_dashboard_daily')) {
                return Http::response($daily, 200, ['Content-Range' => '0-89/90']);
            }
            if ($request->method() === 'HEAD') {
                return Http::response('', 200, ['Content-Range' => '0-0/10']);
            }

            return Http::response([], 200, ['Content-Range' => '0-0/0']);
        });

        $overview = app(SupabaseAdminRepository::class)->overview(90, false);

        $this->assertCount(90, $overview['daily']);
        $this->assertSame(90, $overview['days']);
        Http::assertSent(fn (ClientRequest $request): bool => str_contains($request->url(), '/rest/v1/admin_dashboard_daily')
            && str_contains($request->url(), 'limit=100'));
    }

    public function test_audit_metadata_drops_passwords_and_tokens(): void
    {
        Http::fake([
            'https://cyvora.test/rest/v1/admin_audit_logs' => Http::response([], 201),
        ]);
        $request = Request::create('/admin/users', 'GET');
        $actor = new AdminIdentity(
            '550e8400-e29b-41d4-a716-446655440000',
            'admin@example.test',
            AdminRole::SuperAdmin,
        );

        app(AdminAuditLogger::class)->record(
            $request,
            $actor,
            'user.directory.view',
            'user_directory',
            null,
            'succeeded',
            [
                'count' => 4,
                'access_token' => 'secret-access-value',
                'service_role_key' => 'secret-service-role-value',
                'authorization' => 'Bearer private-value',
                'nested' => ['api_key' => 'secret-api-value', 'safe' => 'visible'],
            ],
        );

        Http::assertSent(function (ClientRequest $sent): bool {
            $payload = $sent->data();

            return str_contains($sent->url(), '/rest/v1/admin_audit_logs')
                && ! str_contains($sent->body(), 'secret-access-value')
                && ! str_contains($sent->body(), 'secret-service-role-value')
                && ! str_contains($sent->body(), 'Bearer private-value')
                && ! str_contains($sent->body(), 'secret-api-value')
                && ($payload['metadata']['count'] ?? null) === 4
                && ($payload['metadata']['nested']['safe'] ?? null) === 'visible';
        });
    }
}
