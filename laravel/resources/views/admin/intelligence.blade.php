@extends('admin.layout')

@section('title', 'Scam intelligence')

@section('content')
    @php($admin = request()->attributes->get('admin'))
    <div class="page-heading">
        <div><p class="eyebrow">TRUSTED INTELLIGENCE</p><h1>Scam intelligence</h1><p>Reviews are submitted to the existing Supabase workflow. The backend enforces reviewer separation and the two-independent-reviewer release gate.</p></div>
    </div>
    <section class="panel">
        <div class="panel-heading"><div><h2>Review queue</h2><p>Redacted submissions only; content is not used in scans until the existing release process completes.</p></div></div>
        @if (count($submissions) === 0)
            <div class="empty-state">The trusted-intelligence service returned no pending submissions.</div>
        @else
            <div class="submission-list">
                @foreach ($submissions as $submission)
                    <article class="submission-card">
                        <div class="submission-head">
                            <div><span class="status-pill status-neutral">{{ $submission['status'] }}</span><span class="status-pill status-neutral">{{ $submission['content_type'] }}</span></div>
                            <small>{{ $submission['created_at'] }}</small>
                        </div>
                        <p class="redacted-content">{{ \Illuminate\Support\Str::limit($submission['redacted_content'], 500) }}</p>
                        <dl class="review-summary">
                            <div><dt>Submission</dt><dd><code>{{ $submission['id'] }}</code></dd></div>
                            <div><dt>Prior reviewers</dt><dd>{{ count($submission['reviews'] ?? []) }}</dd></div>
                            <div><dt>Submitted label</dt><dd>{{ $submission['submitted_label'] }}</dd></div>
                        </dl>
                        @if ($submission['reviewed_by_current_user'] ?? false)
                            <p class="muted">You have already reviewed this example. The backend prevents a second review by the same moderator.</p>
                        @elseif (($submission['reporter_id'] ?? null) === $admin->id)
                            <p class="muted">You cannot review your own submission.</p>
                        @else
                            <form method="post" action="{{ route('admin.intelligence.review') }}" class="review-form">
                                @csrf
                                <input type="hidden" name="submission_id" value="{{ $submission['id'] }}">
                                <label>Decision
                                    <select name="decision" required>
                                        <option value="verified_scam">Verify scam</option>
                                        <option value="verified_legitimate">Verify legitimate</option>
                                        <option value="rejected">Reject</option>
                                        <option value="disputed">Mark disputed</option>
                                    </select>
                                </label>
                                <label>Verification method
                                    <select name="verification_method" required>
                                        <option value="official_source">Official source</option>
                                        <option value="direct_contact">Direct contact</option>
                                        <option value="law_enforcement">Law enforcement</option>
                                        <option value="independent_fact_check">Independent fact check</option>
                                        <option value="other">Other</option>
                                    </select>
                                </label>
                                <label class="field-wide">Evidence reference
                                    <textarea name="evidence_reference" minlength="12" maxlength="2000" required></textarea>
                                </label>
                                <label class="field-wide">Reviewer notes
                                    <textarea name="notes" maxlength="1000"></textarea>
                                </label>
                                <button class="button button-primary" type="submit">Submit independent review</button>
                            </form>
                        @endif
                        @if ($admin->can('intelligence.manage') && $submission['status'] === 'disputed')
                            <form method="post" action="{{ route('admin.intelligence.resolve-dispute') }}" class="review-form destructive-form">
                                @csrf
                                <input type="hidden" name="submission_id" value="{{ $submission['id'] }}">
                                <label>Administrator resolution
                                    <select name="decision" required>
                                        <option value="verified_scam">Verify scam</option>
                                        <option value="verified_legitimate">Verify legitimate</option>
                                    </select>
                                </label>
                                <label>Evidence reference
                                    <textarea name="evidence_reference" minlength="12" maxlength="2000" required></textarea>
                                </label>
                                <label>Type RESOLVE to confirm
                                    <input name="confirmation" pattern="RESOLVE" required>
                                </label>
                                <button class="button button-danger" type="submit">Resolve disputed example</button>
                            </form>
                        @endif
                    </article>
                @endforeach
            </div>
        @endif
    </section>

    <section class="panel">
        <div class="panel-heading"><div><h2>Dataset versions</h2><p>Releases are evaluated and activated only through the trusted Supabase function.</p></div></div>
        @if (count($datasets) === 0)
            <div class="empty-state">No dataset versions were returned for this administrator session.</div>
        @else
            <div class="table-scroll">
                <table><thead><tr><th>Version</th><th>Examples</th><th>Evaluation</th><th>Release</th><th>Metrics</th><th>Actions</th></tr></thead>
                    <tbody>
                    @foreach ($datasets as $dataset)
                        <tr>
                            <td><strong>{{ $dataset['version_label'] }}</strong><small class="row-subtitle">{{ $dataset['id'] }}</small></td>
                            <td>{{ number_format($dataset['example_count']) }}</td>
                            <td>{{ $dataset['evaluation_status'] }}</td>
                            <td>{{ $dataset['release_status'] }}</td>
                            <td><code>{{ json_encode($dataset['evaluation_metrics'], JSON_UNESCAPED_SLASHES) }}</code></td>
                            <td class="action-cell">
                                @if ($admin->can('intelligence.manage'))
                                    <form method="post" action="{{ route('admin.intelligence.evaluate') }}" class="compact-form stack-form">
                                        @csrf
                                        <input type="hidden" name="dataset_version_id" value="{{ $dataset['id'] }}">
                                        <label>Type EVALUATE<input name="confirmation" pattern="EVALUATE" required></label>
                                        <button class="button button-secondary" type="submit">Evaluate</button>
                                    </form>
                                    @if ($dataset['evaluation_status'] === 'passed')
                                        <form method="post" action="{{ route('admin.intelligence.release') }}" class="compact-form stack-form">
                                            @csrf
                                            <input type="hidden" name="dataset_version_id" value="{{ $dataset['id'] }}">
                                            <label>Type RELEASE<input name="confirmation" pattern="RELEASE" required></label>
                                            <button class="button button-danger" type="submit">Activate version</button>
                                        </form>
                                    @endif
                                @else
                                    <span class="muted">Read only</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        @endif
        <p class="data-caption">{{ number_format($totalDatasets) }} version records. Staging and evaluation do not change production scan results; activation requires the backend evaluation gate.</p>
    </section>
@endsection
