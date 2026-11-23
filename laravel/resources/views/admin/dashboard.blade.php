@extends('admin.layout')

@section('title', 'Overview')

@section('content')
    <div class="page-heading">
        <div>
            <p class="eyebrow">CYVORA OPERATIONS</p>
            <h1>Overview</h1>
            <p>Authorized live data from Supabase. Counts are database-backed, not simulated.</p>
        </div>
        <form class="filter-form" method="get" action="{{ route('admin.dashboard') }}">
            <label for="days">Trend range</label>
            <select id="days" name="days" data-auto-submit>
                @foreach ([7, 30, 90] as $days)
                    <option value="{{ $days }}" @selected(($dashboard['days'] ?? (int) request('days', 30)) === $days)>{{ $days }} days</option>
                @endforeach
            </select>
            <button class="button button-secondary" type="submit">Update</button>
        </form>
    </div>

    @if ($dataError)
        <section class="panel notice-panel">
            <span class="status-pill status-warning">DATA UNAVAILABLE</span>
            <p>{{ $dataError }}</p>
        </section>
    @else
        <section class="metric-grid" aria-label="Current metrics">
            <article class="metric-card"><span>Registered users</span><strong>{{ number_format($dashboard['total_users']) }}</strong><small>All Supabase Auth accounts</small></article>
            <article class="metric-card"><span>Active users</span><strong>{{ number_format($dashboard['active_users_30d']) }}</strong><small>Signed in within 30 days; not suspended</small></article>
            <article class="metric-card"><span>Suspended accounts</span><strong>{{ number_format($dashboard['suspended_users']) }}</strong><small>Current Auth ban status</small></article>
            <article class="metric-card"><span>Total scans</span><strong>{{ number_format($dashboard['total_scans']) }}</strong><small>Persisted scan records</small></article>
            <article class="metric-card metric-alert"><span>High-risk scans</span><strong>{{ number_format($dashboard['high_risk_scans']) }}</strong><small>Risk classification: high</small></article>
            <article class="metric-card"><span>Low-risk scans</span><strong>{{ number_format($dashboard['low_risk_scans']) }}</strong><small>Risk classification: low</small></article>
            <article class="metric-card"><span>Family groups</span><strong>{{ number_format($dashboard['families']) }}</strong><small>Existing family records</small></article>
            <article class="metric-card"><span>Scam reports</span><strong>{{ number_format($dashboard['scam_reports']) }}</strong><small>Submitted report records</small></article>
        </section>

        @php
            $daily = collect($dashboard['daily'])->keyBy('day')->take(-14);
            $maximumScans = max(1, (int) $daily->max('scan_count'));
        @endphp
        <div class="content-grid">
            <section class="panel">
                <div class="panel-heading">
                    <div><h2>Activity trends</h2><p>Daily registrations and scan volume for the selected range.</p></div>
                    <span class="status-pill status-neutral">LIVE DATA</span>
                </div>
                @if ($daily->isEmpty())
                    <div class="empty-state">No activity records were returned for this date range.</div>
                @else
                    <div class="trend-list">
                        @foreach ($daily as $day => $row)
                            @php
                                $registrations = (int) $row['registration_count'];
                                $scans = (int) $row['scan_count'];
                            @endphp
                            <div class="trend-row">
                                <time datetime="{{ $day }}">{{ \Illuminate\Support\Carbon::parse($day)->format('M j') }}</time>
                                <span class="trend-count">{{ number_format($registrations) }} users</span>
                                <span class="trend-count">{{ number_format($scans) }} scans</span>
                                <progress max="{{ $maximumScans }}" value="{{ $scans }}" aria-label="{{ $scans }} scans on {{ $day }}"></progress>
                            </div>
                        @endforeach
                    </div>
                @endif
                <p class="data-caption">Generated {{ \Illuminate\Support\Carbon::parse($dashboard['generated_at'])->format('M j, Y H:i') }} UTC.</p>
            </section>
            <section class="panel">
                <div class="panel-heading"><div><h2>Recent admin activity</h2><p>Append-only privileged action events.</p></div><a class="text-link" href="{{ route('admin.audit.index') }}">View log</a></div>
                @forelse (array_slice($dashboard['recent_actions'], 0, 8) as $activity)
                    <div class="activity-row">
                        <span class="activity-mark"></span>
                        <div><strong>{{ str_replace('_', ' ', $activity['action']) }}</strong><small>{{ $activity['actor_role'] ?? 'system' }} · {{ $activity['outcome'] }}</small></div>
                        <time>{{ \Illuminate\Support\Carbon::parse($activity['created_at'])->diffForHumans() }}</time>
                    </div>
                @empty
                    <div class="empty-state">No administrative events have been recorded.</div>
                @endforelse
            </section>
        </div>

        <section class="panel availability-panel">
            <div><h2>System data availability</h2><p>Provider history is available in AI Provider Monitoring. Repository data does not establish live connectivity or billing status.</p></div>
            @if (request()->attributes->get('admin')?->can('providers.view'))
                <a class="button button-secondary" href="{{ route('admin.providers.index') }}">Provider history</a>
            @endif
            <p class="availability-note">Subscriptions, billing, and provider dollar-spend metrics are not represented in the current Supabase schema.</p>
        </section>
    @endif
@endsection
