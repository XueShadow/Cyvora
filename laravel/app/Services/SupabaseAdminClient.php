<?php

namespace App\Services;

use App\Exceptions\SupabaseConfigurationException;
use App\Exceptions\SupabaseRequestException;
use App\Exceptions\SupabaseUnavailableException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use InvalidArgumentException;

final class SupabaseAdminClient
{
    public function isConfigured(bool $requireServiceRole = false): bool
    {
        return filled(config('services.supabase.url'))
            && filled(config('services.supabase.anon_key'))
            && (! $requireServiceRole || filled(config('services.supabase.service_role_key')));
    }

    /**
     * @return array<string, mixed>
     */
    public function signIn(string $email, string $password): array
    {
        return $this->json(
            $this->send(
                'POST',
                'auth/v1/token?grant_type=password',
                false,
                ['email' => $email, 'password' => $password],
            ),
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function refreshSession(string $refreshToken): array
    {
        return $this->json(
            $this->send(
                'POST',
                'auth/v1/token?grant_type=refresh_token',
                false,
                ['refresh_token' => $refreshToken],
            ),
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function currentUser(string $accessToken): array
    {
        return $this->json($this->send('GET', 'auth/v1/user', false, [], [], $accessToken));
    }

    public function signOut(string $accessToken): void
    {
        $this->send('POST', 'auth/v1/logout?scope=local', false, [], [], $accessToken);
    }

    /**
     * @return array<string, mixed>
     */
    public function createMfaChallenge(string $accessToken, string $factorId): array
    {
        return $this->json(
            $this->send(
                'POST',
                'auth/v1/factors/'.rawurlencode($factorId).'/challenge',
                false,
                [],
                [],
                $accessToken,
            ),
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function enrollTotpFactor(string $accessToken): array
    {
        return $this->json(
            $this->send(
                'POST',
                'auth/v1/factors',
                false,
                ['factor_type' => 'totp', 'friendly_name' => 'Cyvora Super Admin'],
                [],
                $accessToken,
            ),
        );
    }

    public function removeMfaFactor(string $accessToken, string $factorId): void
    {
        $this->send(
            'DELETE',
            'auth/v1/factors/'.rawurlencode($factorId),
            false,
            [],
            [],
            $accessToken,
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function verifyMfaChallenge(
        string $accessToken,
        string $factorId,
        string $challengeId,
        string $code,
    ): array {
        return $this->json(
            $this->send(
                'POST',
                'auth/v1/factors/'.rawurlencode($factorId).'/verify',
                false,
                ['challenge_id' => $challengeId, 'code' => $code],
                [],
                $accessToken,
            ),
        );
    }

    public function requestPasswordReset(string $email, string $redirectTo): void
    {
        $path = 'auth/v1/recover?'.http_build_query(['redirect_to' => $redirectTo]);
        $this->send('POST', $path, false, ['email' => $email]);
    }

    public function updatePassword(string $accessToken, string $password): void
    {
        $this->send('PUT', 'auth/v1/user', false, ['password' => $password], [], $accessToken);
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function selectPage(
        string $table,
        array $query,
        int $page,
        int $perPage,
    ): array {
        $this->assertTableName($table);
        $page = max(1, $page);
        $perPage = max(1, min(100, $perPage));
        $offset = ($page - 1) * $perPage;

        $response = $this->send(
            'GET',
            'rest/v1/'.$table,
            true,
            $query + ['limit' => $perPage, 'offset' => $offset],
            ['Prefer' => 'count=exact'],
        );
        $data = $this->json($response);
        $contentRange = $response->header('Content-Range');

        if (! is_string($contentRange) || preg_match('/\/(\d+)$/', $contentRange, $matches) !== 1) {
            throw new SupabaseRequestException(502);
        }

        return [
            'data' => array_values(array_filter($data, 'is_array')),
            'total' => (int) $matches[1],
        ];
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function selectPageAsUser(
        string $table,
        array $query,
        int $page,
        int $perPage,
        string $accessToken,
    ): array {
        $this->assertTableName($table);
        $page = max(1, $page);
        $perPage = max(1, min(100, $perPage));
        $offset = ($page - 1) * $perPage;

        $response = $this->send(
            'GET',
            'rest/v1/'.$table,
            false,
            $query + ['limit' => $perPage, 'offset' => $offset],
            ['Prefer' => 'count=exact'],
            $accessToken,
        );
        $data = $this->json($response);
        $contentRange = $response->header('Content-Range');

        if (! is_string($contentRange) || preg_match('/\/(\d+)$/', $contentRange, $matches) !== 1) {
            throw new SupabaseRequestException(502);
        }

        return [
            'data' => array_values(array_filter($data, 'is_array')),
            'total' => (int) $matches[1],
        ];
    }

    /**
     * @param  array<string, string>  $filters
     */
    public function exactCount(string $table, array $filters = []): int
    {
        $this->assertTableName($table);
        $response = $this->send(
            'HEAD',
            'rest/v1/'.$table,
            true,
            ['select' => 'id'] + $filters,
            ['Prefer' => 'count=exact', 'Range-Unit' => 'items', 'Range' => '0-0'],
        );
        $contentRange = $response->header('Content-Range');

        if (! is_string($contentRange) || preg_match('/\/(\d+)$/', $contentRange, $matches) !== 1) {
            throw new SupabaseRequestException(502);
        }

        return (int) $matches[1];
    }

    /**
     * @param  array<string, mixed>  $values
     */
    public function insert(string $table, array $values): void
    {
        $this->assertTableName($table);
        $this->send(
            'POST',
            'rest/v1/'.$table,
            true,
            $values,
            ['Prefer' => 'return=minimal'],
        );
    }

    /**
     * @param  array<string, string>  $filters
     * @param  array<string, mixed>  $values
     * @return array<int, array<string, mixed>>
     */
    public function updateRows(string $table, array $filters, array $values): array
    {
        $this->assertTableName($table);
        $path = 'rest/v1/'.$table.'?'.http_build_query(['select' => 'id'] + $filters);

        return array_values(array_filter(
            $this->json($this->send(
                'PATCH',
                $path,
                true,
                $values,
                ['Prefer' => 'return=representation'],
            )),
            'is_array',
        ));
    }

    /**
     * @return array<string, mixed>
     */
    public function listAuthUsers(int $page, int $perPage): array
    {
        return $this->json(
            $this->send(
                'GET',
                'auth/v1/admin/users',
                true,
                [],
                [],
                null,
                ['page' => max(1, $page), 'per_page' => max(1, min(100, $perPage))],
            ),
        );
    }

    /**
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    public function updateAuthUser(string $userId, array $values): array
    {
        return $this->json(
            $this->send(
                'PUT',
                'auth/v1/admin/users/'.rawurlencode($userId),
                true,
                $values,
            ),
        );
    }

    /**
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    public function createAuthUser(array $values): array
    {
        return $this->json(
            $this->send('POST', 'auth/v1/admin/users', true, $values),
        );
    }

    public function deleteAuthUser(string $userId): void
    {
        $this->send(
            'DELETE',
            'auth/v1/admin/users/'.rawurlencode($userId),
            true,
        );
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function callFunction(string $name, array $body, string $accessToken): array
    {
        if (preg_match('/^[a-z0-9-]+$/', $name) !== 1) {
            throw new InvalidArgumentException('Invalid Supabase function name.');
        }

        return $this->json(
            $this->send(
                'POST',
                'functions/v1/'.$name,
                false,
                $body,
                [],
                $accessToken,
            ),
        );
    }

    private function assertTableName(string $table): void
    {
        if (preg_match('/^[a-z_][a-z0-9_]*$/', $table) !== 1) {
            throw new InvalidArgumentException('Invalid Supabase table name.');
        }
    }

    /**
     * @param  array<string, mixed>  $body
     * @param  array<string, string>  $headers
     * @param  array<string, int>  $query
     */
    private function send(
        string $method,
        string $path,
        bool $serviceRole = false,
        array $body = [],
        array $headers = [],
        ?string $accessToken = null,
        array $query = [],
    ): Response {
        $url = rtrim((string) config('services.supabase.url'), '/');
        $apiKey = $serviceRole
            ? config('services.supabase.service_role_key')
            : config('services.supabase.anon_key');
        $urlComponents = parse_url($url);

        if (
            $url === ''
            || ! is_array($urlComponents)
            || ! in_array($urlComponents['scheme'] ?? null, ['http', 'https'], true)
            || ! is_string($urlComponents['host'] ?? null)
            || isset($urlComponents['user'])
            || isset($urlComponents['pass'])
            || (config('app.env') === 'production' && ($urlComponents['scheme'] ?? null) !== 'https')
            || ! is_string($apiKey)
            || $apiKey === ''
        ) {
            throw new SupabaseConfigurationException;
        }

        $requestHeaders = ['apikey' => $apiKey] + $headers;

        if ($accessToken !== null) {
            $requestHeaders['Authorization'] = 'Bearer '.$accessToken;
        } elseif ($serviceRole) {
            $requestHeaders['Authorization'] = 'Bearer '.$apiKey;
        }

        $request = Http::acceptJson()
            ->withHeaders($requestHeaders)
            ->timeout((int) config('services.supabase.timeout', 5))
            ->connectTimeout((int) config('services.supabase.connect_timeout', 2));
        $endpoint = $url.'/'.$path;

        try {
            $response = match (strtoupper($method)) {
                'GET' => $request->get($endpoint, $query + $body),
                'HEAD' => $request->head($endpoint, $query + $body),
                'POST' => $request->post($endpoint, $body),
                'PUT' => $request->put($endpoint, $body),
                'PATCH' => $request->patch($endpoint, $body),
                'DELETE' => $request->delete($endpoint),
                default => throw new InvalidArgumentException('Unsupported Supabase HTTP method.'),
            };
        } catch (ConnectionException $exception) {
            throw new SupabaseUnavailableException($exception);
        }

        if (! $response->successful()) {
            Log::warning('Supabase admin service request failed.', [
                'method' => strtoupper($method),
                'status' => $response->status(),
            ]);

            throw new SupabaseRequestException($response->status());
        }

        return $response;
    }

    /**
     * @return array<string, mixed>
     */
    private function json(Response $response): array
    {
        $data = $response->json();

        if (! is_array($data)) {
            if ($response->noContent() || $response->body() === '') {
                return [];
            }

            throw new SupabaseRequestException(502);
        }

        return $data;
    }
}
