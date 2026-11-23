@extends('admin.layout')

@section('title', 'Account deletion requests')

@section('content')
    <div class="page-heading">
        <div><p class="eyebrow">SENSITIVE WORKFLOWS</p><h1>Account deletion requests</h1><p>Deletion requires an independent Super Admin review and an additional typed confirmation. Deleting an Auth account cascades to its linked Supabase data.</p></div>
    </div>
    @if (count($requests) === 0)
        <section class="panel empty-state">No deletion requests are pending.</section>
    @else
        <section class="deletion-list">
            @foreach ($requests as $item)
                <article class="panel deletion-card">
                    <div class="panel-heading">
                        <div><h2>Request <code>{{ $item['id'] }}</code></h2><p>Created {{ $item['created_at'] }} · requester role: {{ $item['requester_role'] }}</p></div>
                        <span class="status-pill {{ $item['status'] === 'approved' ? 'status-warning' : ($item['status'] === 'completed' ? 'status-success' : 'status-neutral') }}">{{ $item['status'] }}</span>
                    </div>
                    <dl class="review-summary">
                        <div><dt>Target user</dt><dd><code>{{ $item['target_user_id'] }}</code></dd></div>
                        <div><dt>Requested by</dt><dd><code>{{ $item['requester_id'] }}</code></dd></div>
                        <div><dt>Reason</dt><dd>{{ $item['reason'] }}</dd></div>
                        <div><dt>Reviewed by</dt><dd>{{ $item['reviewed_by'] ?? 'Not reviewed' }}</dd></div>
                    </dl>
                    @if ($item['status'] === 'pending')
                        <div class="workflow-actions">
                            <form method="post" action="{{ route('admin.deletion-requests.review', $item['id']) }}" class="stack-form compact-form">
                                @csrf
                                <input type="hidden" name="decision" value="approved">
                                <label>Type APPROVE<input name="confirmation" pattern="APPROVE" required></label>
                                <button class="button button-danger" type="submit">Approve request</button>
                            </form>
                            <form method="post" action="{{ route('admin.deletion-requests.review', $item['id']) }}" class="stack-form compact-form">
                                @csrf
                                <input type="hidden" name="decision" value="rejected">
                                <label>Type REJECT<input name="confirmation" pattern="REJECT" required></label>
                                <button class="button button-secondary" type="submit">Reject request</button>
                            </form>
                        </div>
                    @elseif ($item['status'] === 'approved')
                        <form method="post" action="{{ route('admin.deletion-requests.execute', $item['id']) }}" class="review-form destructive-form">
                            @csrf
                            <label>Confirm target email<input name="email_confirmation" type="email" autocomplete="off" required></label>
                            <label>Type DELETE ACCOUNT<input name="confirmation" pattern="DELETE ACCOUNT" required></label>
                            <button class="button button-danger" type="submit">Permanently delete account data</button>
                        </form>
                    @elseif ($item['status'] === 'executing' || $item['status'] === 'failed')
                        <p class="notice notice-warning">This request needs operational follow-up before another deletion attempt.</p>
                    @endif
                </article>
            @endforeach
        </section>
    @endif
@endsection
