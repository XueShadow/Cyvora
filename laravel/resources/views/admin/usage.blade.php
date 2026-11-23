@extends('admin.layout')

@section('title', 'Usage analytics')

@section('content')
    <div class="page-heading">
        <div><p class="eyebrow">USAGE AND ANALYTICS</p><h1>Usage metrics</h1><p>Counts are read from Supabase's provider and global daily usage tables. Per-user usage and monetary estimates are intentionally excluded.</p></div>
    </div>
    <section class="panel">
        <div class="panel-heading"><div><h2>Global daily requests</h2><p>Current aggregate counters recorded by the AI request guardrails.</p></div></div>
        @if (count($global) === 0)
            <div class="empty-state">No global usage records are available.</div>
        @else
            <div class="table-scroll">
                <table><thead><tr><th>Date</th><th>Requests</th></tr></thead><tbody>
                    @foreach ($global as $row)
                        <tr><td>{{ $row['usage_date'] }}</td><td>{{ $row['request_count'] }}</td></tr>
                    @endforeach
                </tbody></table>
            </div>
        @endif
    </section>
    <section class="panel">
        <div class="panel-heading"><div><h2>Provider daily requests</h2><p>Provider-level counts from the existing runtime usage table.</p></div></div>
        @if (count($providers) === 0)
            <div class="empty-state">No provider usage records are available.</div>
        @else
            <div class="table-scroll">
                <table><thead><tr><th>Date</th><th>Provider</th><th>Requests</th></tr></thead><tbody>
                    @foreach ($providers as $row)
                        <tr><td>{{ $row['usage_date'] }}</td><td>{{ $row['provider'] }}</td><td>{{ $row['request_count'] }}</td></tr>
                    @endforeach
                </tbody></table>
            </div>
        @endif
    </section>
@endsection
