@extends('admin.layout')

@section('title', 'Family protection')

@section('content')
    <div class="page-heading">
        <div><p class="eyebrow">ACCOUNT SAFETY</p><h1>Family protection</h1><p>Group-level metadata only. Private family communications are not accessible from this panel.</p></div>
    </div>
    <section class="panel table-panel">
        <div class="table-summary">{{ number_format($total) }} family groups</div>
        @if (count($families) === 0)
            <div class="empty-state">No family groups are available.</div>
        @else
            <div class="table-scroll">
                <table>
                    <thead><tr><th>Name</th><th>Members</th><th>Pending invitations</th><th>Created</th><th></th></tr></thead>
                    <tbody>
                    @foreach ($families as $family)
                        <tr>
                            <td><strong>{{ $family['name'] }}</strong><small class="row-subtitle">{{ $family['family_id'] }}</small></td>
                            <td>{{ number_format($family['member_count']) }}</td>
                            <td>{{ number_format($family['pending_invites']) }}</td>
                            <td>{{ $family['created_at'] }}</td>
                            <td><a class="text-link" href="{{ route('admin.families.show', $family['family_id']) }}">Review security metadata</a></td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
        @php($pageSize = 25)
        @if ($total > $pageSize)
            <nav class="pagination" aria-label="Family pages">
                @if ($page > 1)<a class="button button-secondary" href="{{ request()->fullUrlWithQuery(['page' => $page - 1]) }}">Previous</a>@endif
                <span>Page {{ $page }} of {{ (int) ceil($total / $pageSize) }}</span>
                @if ($page * $pageSize < $total)<a class="button button-secondary" href="{{ request()->fullUrlWithQuery(['page' => $page + 1]) }}">Next</a>@endif
            </nav>
        @endif
    </section>
@endsection
