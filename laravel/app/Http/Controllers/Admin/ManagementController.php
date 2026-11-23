<?php

namespace App\Http\Controllers\Admin;

use App\Admin\AdminIdentity;
use App\Admin\AdminRole;
use App\Exceptions\SupabaseRequestException;
use App\Http\Controllers\Controller;
use App\Services\AdminAuditLogger;
use App\Services\SupabaseAdminClient;
use App\Services\SupabaseAdminRepository;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\View\View;

class ManagementController extends Controller
{
    public function users(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'in:active,suspended'],
            'page' => ['nullable', 'integer', 'min:1'],
        ]);
        $result = $repository->users($filters, (int) ($filters['page'] ?? 1));
        $audit->record($request, $this->admin($request), 'user.directory.view', 'user_directory', null, 'succeeded');

        return view('admin.users', [
            'users' => $result['data'],
            'total' => $result['total'],
            'page' => (int) ($filters['page'] ?? 1),
            'filters' => $filters,
            'admin' => $this->admin($request),
            'canManageUsers' => $this->admin($request)->can('users.manage'),
            'canRequestDeletion' => $this->admin($request)->can('users.delete.request'),
        ]);
    }

    public function suspendUser(
        Request $request,
        string $userId,
        SupabaseAdminRepository $repository,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'email_confirmation' => ['required', 'email', 'max:254'],
            'ban_duration' => ['required', 'in:24h,168h,720h,876000h'],
        ]);
        $user = $repository->user($userId);
        $actor = $this->admin($request);

        if ($user === null) {
            abort(404);
        }
        if ($userId === $actor->id || ! $this->canManageTarget($actor, $user)) {
            abort(403);
        }
        if (! hash_equals(mb_strtolower($user['email']), mb_strtolower($data['email_confirmation']))) {
            return back()->withErrors(['email_confirmation' => 'The email confirmation did not match.']);
        }

        $audit->record($request, $actor, 'user.suspend', 'user', $userId, 'started', [
            'duration' => $data['ban_duration'],
        ]);

        try {
            $client->updateAuthUser($userId, ['ban_duration' => $data['ban_duration']]);
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'user.suspend', 'user', $userId, 'failed', [
                'http_status' => $exception->status,
            ]);

            throw $exception;
        }

        $audit->record($request, $actor, 'user.suspend', 'user', $userId, 'succeeded', [
            'duration' => $data['ban_duration'],
        ]);

        return back()->with('status', 'The account suspension was applied.');
    }

    public function reactivateUser(
        Request $request,
        string $userId,
        SupabaseAdminRepository $repository,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'email_confirmation' => ['required', 'email', 'max:254'],
        ]);
        $user = $repository->user($userId);
        $actor = $this->admin($request);

        if ($user === null) {
            abort(404);
        }
        if ($userId === $actor->id || ! $this->canManageTarget($actor, $user)) {
            abort(403);
        }
        if (! hash_equals(mb_strtolower($user['email']), mb_strtolower($data['email_confirmation']))) {
            return back()->withErrors(['email_confirmation' => 'The email confirmation did not match.']);
        }

        $audit->record($request, $actor, 'user.reactivate', 'user', $userId, 'started');

        try {
            $client->updateAuthUser($userId, ['ban_duration' => 'none']);
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'user.reactivate', 'user', $userId, 'failed', [
                'http_status' => $exception->status,
            ]);

            throw $exception;
        }

        $audit->record($request, $actor, 'user.reactivate', 'user', $userId, 'succeeded');

        return back()->with('status', 'The account was reactivated.');
    }

    public function requestDeletion(
        Request $request,
        string $userId,
        SupabaseAdminRepository $repository,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'email_confirmation' => ['required', 'email', 'max:254'],
            'reason' => ['required', 'string', 'min:12', 'max:500'],
        ]);
        $user = $repository->user($userId);
        $actor = $this->admin($request);

        if ($user === null) {
            abort(404);
        }
        if ($userId === $actor->id || ! $this->canManageTarget($actor, $user)) {
            abort(403);
        }
        if (! hash_equals(mb_strtolower($user['email']), mb_strtolower($data['email_confirmation']))) {
            return back()->withErrors(['email_confirmation' => 'The email confirmation did not match.']);
        }

        $requestId = (string) Str::uuid();
        $audit->record($request, $actor, 'user.deletion_request', 'user', $userId, 'started', [
            'workflow_request_id' => $requestId,
        ]);

        try {
            $client->insert('admin_account_deletion_requests', [
                'id' => $requestId,
                'target_user_id' => $userId,
                'requester_id' => $actor->id,
                'requester_role' => $actor->role->value,
                'reason' => $data['reason'],
                'status' => 'pending',
            ]);
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'user.deletion_request', 'user', $userId, 'failed', [
                'http_status' => $exception->status,
                'workflow_request_id' => $requestId,
            ]);

            throw $exception;
        }

        $audit->record($request, $actor, 'user.deletion_request', 'user', $userId, 'succeeded', [
            'workflow_request_id' => $requestId,
        ]);

        return back()->with('status', 'A deletion request was recorded for independent review. No account data has been deleted.');
    }

    public function families(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $page = max(1, $request->integer('page', 1));
        $result = $repository->families($page);
        $audit->record($request, $this->admin($request), 'family.directory.view', 'family_directory', null, 'succeeded');

        return view('admin.families', [
            'families' => $result['data'],
            'total' => $result['total'],
            'page' => $page,
        ]);
    }

    public function familyDetails(
        Request $request,
        string $familyId,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        abort_unless(Str::isUuid($familyId), 404);

        $members = $repository->familyMembers($familyId);
        abort_if($members === [], 404);
        $audit->record($request, $this->admin($request), 'family.security.view', 'family', $familyId, 'succeeded');

        return view('admin.family-details', [
            'familyId' => $familyId,
            'members' => $members,
            'invitations' => $repository->familyInvitations($familyId),
            'securityEvents' => $repository->familySecurityEvents($familyId),
        ]);
    }

    public function revokeInvitation(
        Request $request,
        string $invitationId,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $request->validate(['confirmation' => ['required', 'in:REVOKE']]);
        abort_unless(Str::isUuid($invitationId), 404);
        $actor = $this->admin($request);
        $audit->record($request, $actor, 'family_invitation.revoke', 'family_invitation', $invitationId, 'started');
        $rows = $repository->revokeFamilyInvitation($invitationId);

        if ($rows === []) {
            $audit->record($request, $actor, 'family_invitation.revoke', 'family_invitation', $invitationId, 'failed');

            return back()->withErrors(['confirmation' => 'The invitation is already accepted, expired, or unavailable.']);
        }

        $audit->record($request, $actor, 'family_invitation.revoke', 'family_invitation', $invitationId, 'succeeded');

        return back()->with('status', 'The pending invitation was revoked.');
    }

    public function scans(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $page = max(1, $request->integer('page', 1));
        $result = $repository->scans($page);
        $audit->record($request, $this->admin($request), 'scan_history.view', 'scan_history', null, 'succeeded');

        return view('admin.table', [
            'title' => 'Scan history',
            'description' => 'Metadata only; message contents and private report descriptions are not available in this view.',
            'columns' => [
                'id' => 'Scan ID',
                'user_id' => 'User ID',
                'scan_type' => 'Type',
                'risk_level' => 'Risk',
                'created_at' => 'Created',
            ],
            'rows' => $result['data'],
            'page' => $page,
            'total' => $result['total'],
        ]);
    }

    public function reports(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $page = max(1, $request->integer('page', 1));
        $result = $repository->reports($page);
        $audit->record($request, $this->admin($request), 'scam_reports.view', 'scam_reports', null, 'succeeded');

        return view('admin.table', [
            'title' => 'Scam reports',
            'description' => 'Privacy-conscious report metadata. Report descriptions and reporter identities are intentionally excluded.',
            'columns' => [
                'id' => 'Report ID',
                'category' => 'Category',
                'family_id' => 'Family ID',
                'created_at' => 'Created',
            ],
            'rows' => $result['data'],
            'page' => $page,
            'total' => $result['total'],
        ]);
    }

    public function intelligence(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminSession $adminSession,
        AdminAuditLogger $audit,
    ): View {
        $queue = $repository->intelligenceQueue((string) $adminSession->accessToken($request));
        $datasets = $repository->datasets((string) $adminSession->accessToken($request));
        $audit->record($request, $this->admin($request), 'intelligence.queue.view', 'submissions', null, 'succeeded');

        return view('admin.intelligence', [
            'submissions' => $queue['submissions'] ?? [],
            'datasets' => $datasets['data'],
            'totalDatasets' => $datasets['total'],
        ]);
    }

    public function reviewExample(
        Request $request,
        AdminSession $adminSession,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'submission_id' => ['required', 'uuid'],
            'decision' => ['required', 'in:verified_scam,verified_legitimate,rejected,disputed'],
            'verification_method' => ['required', 'in:official_source,direct_contact,law_enforcement,independent_fact_check,other'],
            'evidence_reference' => ['required', 'string', 'min:12', 'max:2000'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);
        $actor = $this->admin($request);
        $audit->record($request, $actor, 'intelligence.review', 'submission', $data['submission_id'], 'started');

        try {
            $result = $client->callFunction(
                'scam-intelligence',
                ['action' => 'review_example'] + $data,
                (string) $adminSession->accessToken($request),
            );
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'intelligence.review', 'submission', $data['submission_id'], 'failed', [
                'http_status' => $exception->status,
            ]);

            return back()->withErrors(['decision' => 'The existing review service rejected the review. Check eligibility and try again.']);
        }

        $audit->record($request, $actor, 'intelligence.review', 'submission', $data['submission_id'], 'succeeded', [
            'decision' => $data['decision'],
        ]);

        return back()->with('status', $result['message'] ?? 'The review was submitted to the trusted-intelligence workflow.');
    }

    public function resolveDispute(
        Request $request,
        AdminSession $adminSession,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'submission_id' => ['required', 'uuid'],
            'decision' => ['required', 'in:verified_scam,verified_legitimate'],
            'evidence_reference' => ['required', 'string', 'min:12', 'max:2000'],
            'confirmation' => ['required', 'in:RESOLVE'],
        ]);
        $actor = $this->admin($request);
        $audit->record($request, $actor, 'intelligence.resolve_dispute', 'submission', $data['submission_id'], 'started');

        try {
            $result = $client->callFunction(
                'scam-intelligence',
                [
                    'action' => 'resolve_dispute',
                    'submission_id' => $data['submission_id'],
                    'decision' => $data['decision'],
                    'evidence_reference' => $data['evidence_reference'],
                ],
                (string) $adminSession->accessToken($request),
            );
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'intelligence.resolve_dispute', 'submission', $data['submission_id'], 'failed', [
                'http_status' => $exception->status,
            ]);

            return back()->withErrors(['confirmation' => 'The dispute could not be resolved by the trusted-intelligence service.']);
        }

        $audit->record($request, $actor, 'intelligence.resolve_dispute', 'submission', $data['submission_id'], 'succeeded');

        return back()->with('status', $result['message'] ?? 'The dispute was resolved.');
    }

    public function evaluateDataset(
        Request $request,
        AdminSession $adminSession,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'dataset_version_id' => ['required', 'uuid'],
            'confirmation' => ['required', 'in:EVALUATE'],
        ]);
        $actor = $this->admin($request);
        $audit->record($request, $actor, 'intelligence.evaluate_dataset', 'dataset_version', $data['dataset_version_id'], 'started');

        try {
            $result = $client->callFunction(
                'scam-intelligence',
                ['action' => 'evaluate_dataset', 'dataset_version_id' => $data['dataset_version_id']],
                (string) $adminSession->accessToken($request),
            );
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'intelligence.evaluate_dataset', 'dataset_version', $data['dataset_version_id'], 'failed', [
                'http_status' => $exception->status,
            ]);

            return back()->withErrors(['confirmation' => 'The existing evaluation gate rejected this request.']);
        }

        $audit->record($request, $actor, 'intelligence.evaluate_dataset', 'dataset_version', $data['dataset_version_id'], 'succeeded');

        return back()->with('status', $result['message'] ?? 'Dataset evaluation completed.');
    }

    public function releaseDataset(
        Request $request,
        AdminSession $adminSession,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'dataset_version_id' => ['required', 'uuid'],
            'confirmation' => ['required', 'in:RELEASE'],
        ]);
        $actor = $this->admin($request);
        $audit->record($request, $actor, 'intelligence.release_dataset', 'dataset_version', $data['dataset_version_id'], 'started');

        try {
            $result = $client->callFunction(
                'scam-intelligence',
                ['action' => 'release_dataset', 'dataset_version_id' => $data['dataset_version_id']],
                (string) $adminSession->accessToken($request),
            );
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'intelligence.release_dataset', 'dataset_version', $data['dataset_version_id'], 'failed', [
                'http_status' => $exception->status,
            ]);

            return back()->withErrors(['confirmation' => 'Only a dataset that passed evaluation can be activated.']);
        }

        $audit->record($request, $actor, 'intelligence.release_dataset', 'dataset_version', $data['dataset_version_id'], 'succeeded');

        return back()->with('status', $result['message'] ?? 'The dataset was released.');
    }

    public function providers(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $result = $repository->providerHealth();
        $audit->record($request, $this->admin($request), 'provider.health.view', 'provider_health', null, 'succeeded');

        return view('admin.table', [
            'title' => 'AI provider monitoring',
            'description' => 'Historical attempts only. This is not a live connectivity check, configuration editor, billing view, or claim that a provider is operational.',
            'columns' => [
                'day' => 'Day',
                'provider_type' => 'Type',
                'provider' => 'Provider',
                'status' => 'Last recorded status',
                'attempt_count' => 'Attempts',
                'average_duration_ms' => 'Average latency (ms)',
            ],
            'rows' => $result['data'],
            'page' => 1,
            'total' => $result['total'],
        ]);
    }

    public function usage(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $usage = $repository->usage();
        $audit->record($request, $this->admin($request), 'usage.metrics.view', 'usage_metrics', null, 'succeeded');

        return view('admin.usage', $usage);
    }

    public function securityEvents(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $page = max(1, $request->integer('page', 1));
        $result = $repository->securityEvents($page);
        $audit->record($request, $this->admin($request), 'security.events.view', 'security_events', null, 'succeeded');

        return view('admin.table', [
            'title' => 'Security events',
            'description' => 'Failed and denied administrative actions. Secret values are excluded from audit metadata.',
            'columns' => [
                'created_at' => 'Time',
                'actor_id' => 'Administrator',
                'actor_role' => 'Role',
                'action' => 'Action',
                'target_type' => 'Target type',
                'target_id' => 'Target',
                'outcome' => 'Outcome',
                'request_id' => 'Request ID',
            ],
            'rows' => $result['data'],
            'page' => $page,
            'total' => $result['total'],
        ]);
    }

    public function auditLogs(Request $request, SupabaseAdminRepository $repository): View
    {
        $page = max(1, $request->integer('page', 1));
        $result = $repository->auditLogs($page);

        return view('admin.table', [
            'title' => 'Administrative audit log',
            'description' => 'Append-only record of privileged Super Admin operations.',
            'columns' => [
                'created_at' => 'Time',
                'actor_id' => 'Administrator',
                'actor_role' => 'Role',
                'action' => 'Action',
                'target_type' => 'Target type',
                'target_id' => 'Target',
                'outcome' => 'Outcome',
                'request_id' => 'Request ID',
            ],
            'rows' => $result['data'],
            'page' => $page,
            'total' => $result['total'],
        ]);
    }

    public function deletionRequests(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $requests = $repository->deletionRequests();
        $audit->record($request, $this->admin($request), 'user.deletion_requests.view', 'deletion_requests', null, 'succeeded');

        return view('admin.deletion-requests', ['requests' => $requests]);
    }

    public function reviewDeletionRequest(
        Request $request,
        string $requestId,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'decision' => ['required', 'in:approved,rejected'],
            'confirmation' => ['required', 'in:APPROVE,REJECT'],
        ]);
        abort_unless(Str::isUuid($requestId), 404);
        abort_unless(
            ($data['decision'] === 'approved' && $data['confirmation'] === 'APPROVE')
            || ($data['decision'] === 'rejected' && $data['confirmation'] === 'REJECT'),
            422,
        );

        $item = $repository->deletionRequest($requestId);
        $actor = $this->admin($request);
        if (
            $item === null
            || $item['status'] !== 'pending'
            || $item['requester_id'] === $actor->id
            || $item['target_user_id'] === $actor->id
        ) {
            abort(409);
        }

        $audit->record($request, $actor, 'user.deletion_request.review', 'deletion_request', $requestId, 'started', [
            'decision' => $data['decision'],
        ]);
        $updated = $repository->updateDeletionRequest($requestId, 'pending', [
            'status' => $data['decision'],
            'reviewed_by' => $actor->id,
            'reviewed_at' => now()->toIso8601String(),
        ]);

        if ($updated === []) {
            $audit->record($request, $actor, 'user.deletion_request.review', 'deletion_request', $requestId, 'failed');

            return back()->withErrors(['confirmation' => 'The request changed before it could be reviewed. Refresh and try again.']);
        }

        $audit->record($request, $actor, 'user.deletion_request.review', 'deletion_request', $requestId, 'succeeded', [
            'decision' => $data['decision'],
        ]);

        return back()->with('status', 'The deletion request was '.$data['decision'].'.');
    }

    public function executeDeletionRequest(
        Request $request,
        string $requestId,
        SupabaseAdminRepository $repository,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'email_confirmation' => ['required', 'email', 'max:254'],
            'confirmation' => ['required', 'in:DELETE ACCOUNT'],
        ]);
        abort_unless(Str::isUuid($requestId), 404);

        $item = $repository->deletionRequest($requestId);
        $actor = $this->admin($request);
        if (
            $item === null
            || $item['status'] !== 'approved'
            || $item['requester_id'] === $actor->id
            || $item['target_user_id'] === $actor->id
            || ! is_string($item['reviewed_by'] ?? null)
        ) {
            abort(409);
        }

        $target = $repository->user($item['target_user_id']);
        if (
            $target === null
            || ! hash_equals(mb_strtolower($target['email']), mb_strtolower($data['email_confirmation']))
        ) {
            return back()->withErrors(['email_confirmation' => 'The approved target account could not be confirmed.']);
        }

        $audit->record($request, $actor, 'user.deletion.execute', 'user', $item['target_user_id'], 'started', [
            'deletion_request_id' => $requestId,
        ]);
        $markedExecuting = $repository->updateDeletionRequest($requestId, 'approved', [
            'status' => 'executing',
        ]);
        if ($markedExecuting === []) {
            return back()->withErrors(['confirmation' => 'The request is no longer approved for execution.']);
        }

        try {
            $client->deleteAuthUser($item['target_user_id']);
        } catch (SupabaseRequestException $exception) {
            $repository->updateDeletionRequest($requestId, 'executing', ['status' => 'failed']);
            $audit->record($request, $actor, 'user.deletion.execute', 'user', $item['target_user_id'], 'failed', [
                'http_status' => $exception->status,
                'deletion_request_id' => $requestId,
            ]);

            return back()->withErrors(['confirmation' => 'Supabase rejected account deletion. The request is marked failed for follow-up.']);
        }

        $repository->updateDeletionRequest($requestId, 'executing', ['status' => 'completed']);
        $audit->record($request, $actor, 'user.deletion.execute', 'user', $item['target_user_id'], 'succeeded', [
            'deletion_request_id' => $requestId,
        ]);

        return back()->with('status', 'The approved account deletion was completed.');
    }

    public function admins(
        Request $request,
        SupabaseAdminRepository $repository,
        AdminAuditLogger $audit,
    ): View {
        $page = max(1, $request->integer('page', 1));
        $result = $repository->authAdmins($page);
        $audit->record($request, $this->admin($request), 'admin.directory.view', 'admin_directory', null, 'succeeded');

        return view('admin.admins', [
            'admins' => $result['data'],
            'nextPage' => $result['next_page'],
            'roles' => AdminRole::cases(),
        ]);
    }

    public function assignAdminRole(
        Request $request,
        SupabaseAdminRepository $repository,
        SupabaseAdminClient $client,
        AdminAuditLogger $audit,
    ): RedirectResponse {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:254'],
            'role' => ['required', 'in:super_admin,admin,moderator,support_admin'],
            'email_confirmation' => ['required', 'email', 'max:254'],
        ]);
        if (! hash_equals(mb_strtolower($data['email']), mb_strtolower($data['email_confirmation']))) {
            return back()->withErrors(['email_confirmation' => 'The email confirmation did not match.']);
        }

        $user = $repository->userByEmail($data['email']);
        if (
            $user === null
            || ! is_string($user['id'] ?? null)
            || ! is_string($user['email'] ?? null)
            || mb_strtolower($user['email']) !== mb_strtolower($data['email'])
            || ! is_string($user['email_confirmed_at'] ?? null)
            || $user['email_confirmed_at'] === ''
        ) {
            return back()->withErrors(['email' => 'No matching Supabase account was found.']);
        }

        $actor = $this->admin($request);
        if ($user['id'] === $actor->id) {
            abort(403);
        }

        $audit->record($request, $actor, 'admin.role_change', 'admin_account', $user['id'], 'started', [
            'new_role' => $data['role'],
        ]);

        try {
            $client->updateAuthUser($user['id'], [
                'app_metadata' => ['role' => $data['role']],
            ]);
        } catch (SupabaseRequestException $exception) {
            $audit->record($request, $actor, 'admin.role_change', 'admin_account', $user['id'], 'failed', [
                'http_status' => $exception->status,
                'new_role' => $data['role'],
            ]);

            throw $exception;
        }

        $audit->record($request, $actor, 'admin.role_change', 'admin_account', $user['id'], 'succeeded', [
            'new_role' => $data['role'],
        ]);

        return back()->with('status', 'The server-assigned administrator role was updated.');
    }

    private function admin(Request $request): AdminIdentity
    {
        $admin = $request->attributes->get('admin');
        abort_unless($admin instanceof AdminIdentity, 403);

        return $admin;
    }

    /**
     * @param  array<string, mixed>  $user
     */
    private function canManageTarget(AdminIdentity $actor, array $user): bool
    {
        return ($user['admin_role'] ?? null) === null
            || $actor->role === AdminRole::SuperAdmin;
    }
}
