@extends('admin.layout')

@section('title', 'User management')

@section('content')
    @php($admin = request()->attributes->get('admin'))
    <div class="page-heading">
        <div><p class="eyebrow">CYVORA ACCOUNTS</p><h1>User management</h1><p>Server-side filtered Supabase Auth accounts. Passwords and authentication tokens are never returned.</p></div>
    </div>
    <section class="panel">
        <form method="get" action="{{ route('admin.users.index') }}" class="filter-row">
            <label for="user-search">Email search</label>
            <input id="user-search" name="search" type="search" maxlength="100" value="{{ $filters['search'] ?? '' }}" placeholder="name@example.com">
            <label for="user-status">Account status</label>
            <select id="user-status" name="status">
                <option value="">All statuses</option>
                <option value="active" @selected(($filters['status'] ?? '') === 'active')>Active</option>
                <option value="suspended" @selected(($filters['status'] ?? '') === 'suspended')>Suspended</option>
            </select>
            <button class="button button-primary" type="submit">Apply filters</button>
        </form>
    </section>
    <section class="panel table-panel">
        <div class="table-summary">{{ number_format($total) }} accounts</div>
        @if (count($users) === 0)
            <div class="empty-state">No matching accounts were found.</div>
        @else
            <div class="table-scroll">
                <table class="user-table">
                    <thead><tr><th>Email</th><th>Status</th><th>Verified</th><th>Last sign in</th><th>Created</th><th>Actions</th></tr></thead>
                    <tbody>
                    @foreach ($users as $user)
                        <tr>
                            <td><strong>{{ $user['email'] }}</strong><small class="row-subtitle">{{ $user['id'] }}</small></td>
                            <td>
                                @if ($user['is_suspended'])
                                    <span class="status-pill status-danger">Suspended</span>
                                @else
                                    <span class="status-pill status-success">Active</span>
                                @endif
                                @if ($user['admin_role'])
                                    <small class="row-subtitle">Role: {{ $user['admin_role'] }}</small>
                                @endif
                            </td>
                            <td>{{ $user['email_confirmed_at'] ? 'Verified' : 'Unverified' }}</td>
                            <td>{{ $user['last_sign_in_at'] ?? 'Never' }}</td>
                            <td>{{ $user['created_at'] }}</td>
                            <td class="action-cell">
                                @if ($canManageUsers && $user['id'] !== $admin->id)
                                    @if ($user['is_suspended'])
                                        <details class="action-details">
                                            <summary>Reactivate</summary>
                                            <form method="post" action="{{ route('admin.users.reactivate', $user['id']) }}" class="stack-form compact-form">
                                                @csrf
                                                <label>Email confirmation</label>
                                                <input type="email" name="email_confirmation" autocomplete="off" required>
                                                <button class="button button-secondary" type="submit">Confirm reactivation</button>
                                            </form>
                                        </details>
                                    @else
                                        <details class="action-details">
                                            <summary>Suspend</summary>
                                            <form method="post" action="{{ route('admin.users.suspend', $user['id']) }}" class="stack-form compact-form">
                                                @csrf
                                                <label>Email confirmation</label>
                                                <input type="email" name="email_confirmation" autocomplete="off" required>
                                                <label>Duration</label>
                                                <select name="ban_duration">
                                                    <option value="24h">24 hours</option>
                                                    <option value="168h">7 days</option>
                                                    <option value="720h">30 days</option>
                                                    <option value="876000h">Indefinite</option>
                                                </select>
                                                <button class="button button-danger" type="submit">Confirm suspension</button>
                                            </form>
                                        </details>
                                    @endif
                                    @if ($canRequestDeletion)
                                        <details class="action-details">
                                            <summary>Request deletion</summary>
                                            <form method="post" action="{{ route('admin.users.deletion-requests.store', $user['id']) }}" class="stack-form compact-form">
                                                @csrf
                                                <label>Email confirmation</label>
                                                <input type="email" name="email_confirmation" autocomplete="off" required>
                                                <label>Reason for independent review</label>
                                                <textarea name="reason" minlength="12" maxlength="500" required></textarea>
                                                <button class="button button-danger" type="submit">Submit request</button>
                                            </form>
                                        </details>
                                    @endif
                                @else
                                    <span class="muted">No account actions</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
        @php($pageSize = 25)
        @if ($total > $pageSize)
            <nav class="pagination" aria-label="User pages">
                @if ($page > 1)<a class="button button-secondary" href="{{ request()->fullUrlWithQuery(['page' => $page - 1]) }}">Previous</a>@endif
                <span>Page {{ $page }} of {{ (int) ceil($total / $pageSize) }}</span>
                @if ($page * $pageSize < $total)<a class="button button-secondary" href="{{ request()->fullUrlWithQuery(['page' => $page + 1]) }}">Next</a>@endif
            </nav>
        @endif
    </section>
@endsection
