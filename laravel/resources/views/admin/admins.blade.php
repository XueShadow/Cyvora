@extends('admin.layout')

@section('title', 'Admin management')

@section('content')
    <div class="page-heading">
        <div><p class="eyebrow">TRUSTED ACCESS</p><h1>Admin management</h1><p>Only confirmed Supabase accounts can receive a role. Role assignments update server-controlled <code>app_metadata</code>, never user-editable profile metadata.</p></div>
    </div>
    <section class="panel">
        <div class="panel-heading"><div><h2>Assign an administrator role</h2><p>Confirm the account email before applying this privileged change.</p></div></div>
        <form method="post" action="{{ route('admin.admins.role') }}" class="review-form">
            @csrf
            <label>Verified account email<input name="email" type="email" maxlength="254" required></label>
            <label>Role
                <select name="role" required>
                    @foreach ($roles as $role)
                        <option value="{{ $role->value }}">{{ str_replace('_', ' ', ucfirst($role->value)) }}</option>
                    @endforeach
                </select>
            </label>
            <label>Type the email again<input name="email_confirmation" type="email" maxlength="254" required></label>
            <button class="button button-danger" type="submit">Apply server-assigned role</button>
        </form>
        <p class="form-help">New accounts must first be created and email-verified through Supabase Auth. The <code>admin:provision</code> command is available for bootstrap operations.</p>
    </section>
    <section class="panel table-panel">
        <div class="panel-heading"><div><h2>Current administrators</h2><p>Only approved role fields and public account status are shown.</p></div></div>
        @if (count($admins) === 0)
            <div class="empty-state">No administrator accounts were returned.</div>
        @else
            <div class="table-scroll">
                <table><thead><tr><th>Email</th><th>Role</th><th>Email status</th><th>Account status</th><th>Created</th></tr></thead>
                    <tbody>
                    @foreach ($admins as $account)
                        <tr>
                            <td><strong>{{ $account['email'] }}</strong><small class="row-subtitle">{{ $account['id'] }}</small></td>
                            <td><span class="status-pill status-neutral">{{ $account['role'] }}</span></td>
                            <td>{{ $account['email_confirmed_at'] ? 'Verified' : 'Unverified' }}</td>
                            <td>{{ $account['banned_until'] && \Illuminate\Support\Carbon::parse($account['banned_until'])->isFuture() ? 'Suspended' : 'Active' }}</td>
                            <td>{{ $account['created_at'] }}</td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
        @if ($nextPage)
            <nav class="pagination"><a class="button button-secondary" href="{{ route('admin.admins.index', ['page' => $nextPage]) }}">Next page</a></nav>
        @endif
    </section>
@endsection
