<?php

namespace App\Services;

use App\Admin\AdminRole;

final class SupabaseAdminRepository
{
    public function __construct(private SupabaseAdminClient $client) {}

    /**
     * @return array<string, mixed>
     */
    public function overview(int $days = 30, bool $includeAdminActivity = true): array
    {
        $now = now();
        $days = max(7, min(90, $days));
        $startDate = $now->copy()->subDays($days - 1)->startOfDay();
        $start = $startDate->toIso8601String();
        $series = $this->client->selectPage(
            'admin_dashboard_daily',
            [
                'select' => 'day,registration_count,scan_count,low_risk_count,review_risk_count,high_risk_count',
                'day' => 'gte.'.$startDate->toDateString(),
                'order' => 'day.asc',
            ],
            1,
            100,
        )['data'];

        return [
            'total_users' => $this->client->exactCount('admin_user_directory'),
            'active_users_30d' => $this->client->exactCount(
                'admin_user_directory',
                [
                    'last_sign_in_at' => 'gte.'.$start,
                    'is_suspended' => 'eq.false',
                ],
            ),
            'suspended_users' => $this->client->exactCount(
                'admin_user_directory',
                ['is_suspended' => 'eq.true'],
            ),
            'total_scans' => $this->client->exactCount('scan_records'),
            'high_risk_scans' => $this->client->exactCount(
                'scan_records',
                ['risk_level' => 'eq.high'],
            ),
            'low_risk_scans' => $this->client->exactCount(
                'scan_records',
                ['risk_level' => 'eq.low'],
            ),
            'families' => $this->client->exactCount('families'),
            'scam_reports' => $this->client->exactCount('scam_reports'),
            'daily' => $series,
            'recent_actions' => $includeAdminActivity ? $this->auditLogs(1)['data'] : [],
            'generated_at' => $now->toIso8601String(),
            'days' => $days,
        ];
    }

    /**
     * @param  array{search?: string, status?: string}  $filters
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function users(array $filters, int $page = 1): array
    {
        $query = [
            'select' => 'id,email,email_confirmed_at,created_at,last_sign_in_at,banned_until,admin_role,is_suspended',
            'order' => 'created_at.desc',
        ];

        if (filled($filters['search'] ?? null)) {
            $search = str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim($filters['search']));
            $query['email'] = 'ilike.*'.$search.'*';
        }

        if (($filters['status'] ?? null) === 'suspended') {
            $query['is_suspended'] = 'eq.true';
        } elseif (($filters['status'] ?? null) === 'active') {
            $query['is_suspended'] = 'eq.false';
        }

        return $this->client->selectPage('admin_user_directory', $query, $page, 25);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function user(string $userId): ?array
    {
        return $this->client->selectPage(
            'admin_user_directory',
            [
                'select' => 'id,email,email_confirmed_at,created_at,last_sign_in_at,banned_until,admin_role,is_suspended',
                'id' => 'eq.'.$userId,
            ],
            1,
            1,
        )['data'][0] ?? null;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function userByEmail(string $email): ?array
    {
        return $this->client->selectPage(
            'admin_user_directory',
            [
                'select' => 'id,email,email_confirmed_at,created_at,banned_until,admin_role,is_suspended',
                'email' => 'eq.'.$email,
            ],
            1,
            1,
        )['data'][0] ?? null;
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function families(int $page = 1): array
    {
        return $this->client->selectPage(
            'admin_family_directory',
            [
                'select' => 'family_id,name,created_at,member_count,pending_invites',
                'order' => 'created_at.desc',
            ],
            $page,
            25,
        );
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function datasets(string $accessToken, int $page = 1): array
    {
        return $this->client->selectPageAsUser(
            'dataset_versions',
            [
                'select' => 'id,version_label,example_count,evaluation_status,evaluation_metrics,release_status,created_at,evaluated_at,approved_at',
                'order' => 'created_at.desc',
            ],
            $page,
            25,
            $accessToken,
        );
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function familyMembers(string $familyId): array
    {
        return $this->client->selectPage(
            'admin_family_membership_directory',
            [
                'select' => 'user_id,role,joined_at',
                'family_id' => 'eq.'.$familyId,
                'order' => 'joined_at.asc',
            ],
            1,
            100,
        )['data'];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function familyInvitations(string $familyId): array
    {
        return $this->client->selectPage(
            'admin_family_invitation_directory',
            [
                'select' => 'id,family_id,created_at,expires_at,accepted_at',
                'family_id' => 'eq.'.$familyId,
                'order' => 'created_at.desc',
            ],
            1,
            100,
        )['data'];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function familySecurityEvents(string $familyId): array
    {
        return $this->client->selectPage(
            'admin_family_security_events',
            [
                'select' => 'day,severity,event_count',
                'family_id' => 'eq.'.$familyId,
                'order' => 'day.desc',
            ],
            1,
            30,
        )['data'];
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function scans(int $page = 1): array
    {
        return $this->client->selectPage(
            'scan_records',
            [
                'select' => 'id,user_id,scan_type,risk_level,created_at',
                'order' => 'created_at.desc',
            ],
            $page,
            50,
        );
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function reports(int $page = 1): array
    {
        return $this->client->selectPage(
            'scam_reports',
            [
                'select' => 'id,category,family_id,created_at',
                'order' => 'created_at.desc',
            ],
            $page,
            50,
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function intelligenceQueue(string $accessToken): array
    {
        return $this->client->callFunction(
            'scam-intelligence',
            ['action' => 'review_queue', 'limit' => 30],
            $accessToken,
        );
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function providerHealth(int $page = 1): array
    {
        return $this->client->selectPage(
            'provider_health_daily',
            [
                'select' => 'day,provider_type,provider,status,attempt_count,average_duration_ms',
                'order' => 'day.desc',
            ],
            $page,
            50,
        );
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function auditLogs(int $page = 1): array
    {
        return $this->client->selectPage(
            'admin_audit_logs',
            [
                'select' => 'id,actor_id,actor_role,action,target_type,target_id,outcome,request_id,created_at',
                'order' => 'created_at.desc',
            ],
            $page,
            50,
        );
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, total: int}
     */
    public function securityEvents(int $page = 1): array
    {
        return $this->client->selectPage(
            'admin_audit_logs',
            [
                'select' => 'id,actor_id,actor_role,action,target_type,target_id,outcome,request_id,created_at',
                'outcome' => 'in.(denied,failed)',
                'order' => 'created_at.desc',
            ],
            $page,
            50,
        );
    }

    /**
     * @return array{providers: array<int, array<string, mixed>>, global: array<int, array<string, mixed>>}
     */
    public function usage(): array
    {
        return [
            'providers' => $this->client->selectPage(
                'ai_provider_daily_usage',
                [
                    'select' => 'provider,usage_date,request_count',
                    'order' => 'usage_date.desc,provider.asc',
                ],
                1,
                100,
            )['data'],
            'global' => $this->client->selectPage(
                'ai_global_daily_usage',
                [
                    'select' => 'usage_date,request_count',
                    'order' => 'usage_date.desc',
                ],
                1,
                30,
            )['data'],
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function deletionRequests(int $page = 1): array
    {
        return $this->client->selectPage(
            'admin_account_deletion_requests',
            [
                'select' => 'id,target_user_id,requester_id,requester_role,reason,status,reviewed_by,reviewed_at,created_at',
                'order' => 'created_at.desc',
            ],
            $page,
            50,
        )['data'];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function deletionRequest(string $requestId): ?array
    {
        return $this->client->selectPage(
            'admin_account_deletion_requests',
            [
                'select' => 'id,target_user_id,requester_id,requester_role,reason,status,reviewed_by,reviewed_at,created_at',
                'id' => 'eq.'.$requestId,
            ],
            1,
            1,
        )['data'][0] ?? null;
    }

    /**
     * @param  array<string, mixed>  $request
     * @return array<int, array<string, mixed>>
     */
    public function revokeFamilyInvitation(string $invitationId): array
    {
        return $this->client->updateRows(
            'family_invites',
            [
                'id' => 'eq.'.$invitationId,
                'accepted_at' => 'is.null',
                'expires_at' => 'gt.'.now()->toIso8601String(),
            ],
            ['expires_at' => now()->toIso8601String()],
        );
    }

    /**
     * @param  array<string, mixed>  $values
     * @return array<int, array<string, mixed>>
     */
    public function updateDeletionRequest(string $requestId, string $status, array $values): array
    {
        return $this->client->updateRows(
            'admin_account_deletion_requests',
            [
                'id' => 'eq.'.$requestId,
                'status' => 'eq.'.$status,
            ],
            $values,
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function authAdmins(int $page = 1): array
    {
        $response = $this->client->listAuthUsers($page, 100);
        $users = $response['users'] ?? [];

        if (! is_array($users)) {
            throw new \UnexpectedValueException('Supabase returned an invalid user directory.');
        }

        $admins = [];
        foreach ($users as $user) {
            if (! is_array($user)) {
                continue;
            }

            $metadata = $user['app_metadata'] ?? [];
            $role = is_array($metadata) ? $metadata['role'] ?? null : null;
            if (! is_string($role) || AdminRole::tryFrom($role) === null) {
                continue;
            }

            $admins[] = [
                'id' => $user['id'] ?? null,
                'email' => $user['email'] ?? null,
                'role' => $role,
                'created_at' => $user['created_at'] ?? null,
                'email_confirmed_at' => $user['email_confirmed_at'] ?? null,
                'banned_until' => $user['banned_until'] ?? null,
            ];
        }

        return [
            'data' => $admins,
            'next_page' => $response['nextPage'] ?? null,
        ];
    }
}
