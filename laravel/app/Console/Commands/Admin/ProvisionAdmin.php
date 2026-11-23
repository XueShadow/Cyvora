<?php

namespace App\Console\Commands\Admin;

use App\Admin\AdminRole;
use App\Exceptions\SupabaseRequestException;
use App\Services\SupabaseAdminClient;
use App\Services\SupabaseAdminRepository;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

#[Signature('admin:provision {email} {role}')]
#[Description('Assign a server-trusted role to an existing verified Supabase account')]
class ProvisionAdmin extends Command
{
    public function handle(
        SupabaseAdminRepository $repository,
        SupabaseAdminClient $client,
    ): int {
        $email = mb_strtolower(trim((string) $this->argument('email')));
        $role = AdminRole::tryFrom((string) $this->argument('role'));

        if ($role === null) {
            $this->error('Role must be one of: super_admin, admin, moderator, support_admin.');

            return self::INVALID;
        }

        if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            $this->error('A valid email address is required.');

            return self::INVALID;
        }

        $user = $repository->userByEmail($email);
        if (
            $user === null
            || ! is_string($user['id'] ?? null)
            || ! is_string($user['email'] ?? null)
            || mb_strtolower($user['email']) !== $email
            || ! is_string($user['email_confirmed_at'] ?? null)
            || $user['email_confirmed_at'] === ''
        ) {
            $this->error('An existing, email-verified Supabase account is required.');

            return self::FAILURE;
        }

        $requestId = (string) Str::uuid();
        $auditMetadata = [
            'role' => $role->value,
            'provisioning_channel' => 'artisan_cli',
        ];
        $this->writeAudit($client, $requestId, $user['id'], 'started', $auditMetadata);

        try {
            $client->updateAuthUser($user['id'], [
                'app_metadata' => ['role' => $role->value],
            ]);
        } catch (SupabaseRequestException $exception) {
            $this->writeAudit($client, $requestId, $user['id'], 'failed', $auditMetadata + [
                'http_status' => $exception->status,
            ]);
            $this->error('Supabase rejected the role assignment.');

            return self::FAILURE;
        }

        $this->writeAudit($client, $requestId, $user['id'], 'succeeded', $auditMetadata);
        $this->info("Assigned the {$role->value} role to the verified account.");

        return self::SUCCESS;
    }

    /**
     * @param  array<string, string|int>  $metadata
     */
    private function writeAudit(
        SupabaseAdminClient $client,
        string $requestId,
        string $userId,
        string $outcome,
        array $metadata,
    ): void {
        $client->insert('admin_audit_logs', [
            'actor_id' => null,
            'actor_role' => null,
            'action' => 'admin.provision',
            'target_type' => 'admin_account',
            'target_id' => $userId,
            'outcome' => $outcome,
            'request_id' => $requestId,
            'metadata' => $metadata,
        ]);
    }
}
