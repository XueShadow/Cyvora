<?php

namespace App\Services;

use App\Admin\AdminIdentity;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

final class AdminAuditLogger
{
    public function __construct(private SupabaseAdminClient $client) {}

    /**
     * @param  array<string, mixed>  $metadata
     */
    public function record(
        Request $request,
        ?AdminIdentity $actor,
        string $action,
        string $targetType,
        ?string $targetId,
        string $outcome,
        array $metadata = [],
    ): string {
        $requestId = $request->header('X-Request-ID');
        if (! is_string($requestId) || ! Str::isUuid($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $this->client->insert('admin_audit_logs', [
            'actor_id' => $actor?->id,
            'actor_role' => $actor?->role->value,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'outcome' => $outcome,
            'request_id' => $requestId,
            'metadata' => $this->sanitize($metadata),
        ]);

        return $requestId;
    }

    /**
     * @param  array<string, mixed>  $metadata
     * @return array<string, mixed>
     */
    private function sanitize(array $metadata): array
    {
        $safe = [];

        foreach ($metadata as $key => $value) {
            if (
                preg_match(
                    '/password|token|secret|credential|api.?key|service.?role.?key|private.?key|authorization|bearer|jwt/i',
                    (string) $key,
                ) === 1
            ) {
                continue;
            }

            if (is_array($value)) {
                $safe[$key] = $this->sanitize($value);
            } elseif (is_scalar($value) || $value === null) {
                $safe[$key] = is_string($value) ? mb_substr($value, 0, 1000) : $value;
            }
        }

        return $safe;
    }
}
