@extends('admin.layout')

@section('title', 'Family security details')

@section('content')
    @php($admin = request()->attributes->get('admin'))
    <div class="page-heading">
        <div><p class="eyebrow">FAMILY PROTECTION</p><h1>Security details</h1><p>Family ID: <code>{{ $familyId }}</code>. Membership IDs and invitation state only; no communication content or invitation tokens are exposed.</p></div>
        <a class="button button-secondary" href="{{ route('admin.families.index') }}">Back to families</a>
    </div>
    <section class="panel">
        <div class="panel-heading"><div><h2>Memberships</h2><p>Visible memberships within this family group.</p></div></div>
        <div class="table-scroll">
            <table><thead><tr><th>User ID</th><th>Relationship</th><th>Joined</th></tr></thead>
                <tbody>
                @foreach ($members as $member)
                    <tr><td>{{ $member['user_id'] }}</td><td>{{ $member['role'] }}</td><td>{{ $member['joined_at'] }}</td></tr>
                @endforeach
                </tbody>
            </table>
        </div>
    </section>
    <section class="panel">
        <div class="panel-heading"><div><h2>Invitations</h2><p>Email addresses and token hashes are intentionally excluded.</p></div></div>
        @if (count($invitations) === 0)
            <div class="empty-state">No invitations were found.</div>
        @else
            <div class="table-scroll">
                <table><thead><tr><th>Invitation ID</th><th>Status</th><th>Created</th><th>Expires</th><th>Action</th></tr></thead>
                    <tbody>
                    @foreach ($invitations as $invitation)
                        @php($pending = $invitation['accepted_at'] === null && \Illuminate\Support\Carbon::parse($invitation['expires_at'])->isFuture())
                        <tr>
                            <td>{{ $invitation['id'] }}</td>
                            <td>{{ $invitation['accepted_at'] ? 'Accepted' : ($pending ? 'Pending' : 'Expired') }}</td>
                            <td>{{ $invitation['created_at'] }}</td>
                            <td>{{ $invitation['expires_at'] }}</td>
                            <td>
                                @if ($pending && $admin->can('families.invites.revoke'))
                                    <form method="post" action="{{ route('admin.family-invitations.revoke', $invitation['id']) }}" class="inline-confirm">
                                        @csrf
                                        <label class="sr-only" for="revoke-{{ $invitation['id'] }}">Type REVOKE</label>
                                        <input id="revoke-{{ $invitation['id'] }}" name="confirmation" pattern="REVOKE" placeholder="Type REVOKE" required>
                                        <button class="button button-danger" type="submit">Revoke</button>
                                    </form>
                                @else
                                    <span class="muted">No action</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </section>
    <section class="panel">
        <div class="panel-heading"><div><h2>Security events</h2><p>Daily counts by severity only; event text and private communications are not exposed.</p></div></div>
        @if (count($securityEvents) === 0)
            <div class="empty-state">No family security events were recorded.</div>
        @else
            <div class="table-scroll">
                <table><thead><tr><th>Day</th><th>Severity</th><th>Events</th></tr></thead>
                    <tbody>
                    @foreach ($securityEvents as $event)
                        <tr><td>{{ $event['day'] }}</td><td>{{ $event['severity'] }}</td><td>{{ $event['event_count'] }}</td></tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </section>
@endsection
