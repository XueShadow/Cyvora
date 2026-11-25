import 'package:material_ui/material_ui.dart';

import '../models/dashboard_models.dart';
import '../presenters/dashboard_presenter.dart';

class TrustedExampleFeedbackDialog extends StatefulWidget {
  const TrustedExampleFeedbackDialog({super.key, required this.contentType});

  final String contentType;

  @override
  State<TrustedExampleFeedbackDialog> createState() =>
      _TrustedExampleFeedbackDialogState();
}

class _TrustedExampleFeedbackDialogState
    extends State<TrustedExampleFeedbackDialog> {
  String? _label;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Help review this result'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your ${widget.contentType} report goes to moderator review. It does not change this scan or train the live detector automatically.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Do not include passwords, one-time codes, or payment details. Sensitive details are removed before storage.',
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _label,
          onChanged: (value) {
            if (value != null) setState(() => _label = value);
          },
          child: Column(
            children: [
              for (final option in const [
                ('scam', 'This is a scam'),
                ('legitimate', 'This is legitimate'),
                ('unsure', 'I am not sure'),
              ])
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(option.$2),
                  value: option.$1,
                ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('submit-trusted-example'),
        onPressed: _label == null ? null : () => Navigator.pop(context, _label),
        child: const Text('Send for review'),
      ),
    ],
  );
}

class TrustedIntelligencePage extends StatefulWidget {
  const TrustedIntelligencePage({
    super.key,
    required this.presenter,
    required this.isModerator,
    required this.isAdmin,
    required this.currentUserId,
  });

  final DashboardPresenter presenter;
  final bool isModerator;
  final bool isAdmin;
  final String? currentUserId;

  @override
  State<TrustedIntelligencePage> createState() =>
      _TrustedIntelligencePageState();
}

class _TrustedIntelligencePageState extends State<TrustedIntelligencePage> {
  List<TrustedExampleStatus> _myExamples = const [];
  List<TrustedReviewSubmission> _queue = const [];
  List<TrustedDatasetVersion> _versions = const [];
  Object? _error;
  bool _loading = true;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final myExamplesFuture = widget.presenter.loadMyTrustedExamples();
      final queueFuture = widget.isModerator
          ? widget.presenter.loadTrustedReviewQueue()
          : Future.value(const <TrustedReviewSubmission>[]);
      final versionsFuture = widget.isAdmin
          ? widget.presenter.loadTrustedDatasetVersions()
          : Future.value(const <TrustedDatasetVersion>[]);
      final results = await Future.wait<Object>([
        myExamplesFuture,
        queueFuture,
        versionsFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _myExamples = results[0] as List<TrustedExampleStatus>;
        _queue = results[1] as List<TrustedReviewSubmission>;
        _versions = results[2] as List<TrustedDatasetVersion>;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _submitReview(
    TrustedReviewSubmission submission,
    String decision,
  ) async {
    final draft = await showDialog<_TrustedReviewDraft>(
      context: context,
      builder: (context) => _TrustedReviewDialog(decision: decision),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _busyIds.add(submission.id);
      _error = null;
    });
    try {
      await widget.presenter.reviewTrustedExample(
        submissionId: submission.id,
        decision: decision,
        verificationMethod: draft.method,
        evidenceReference: draft.evidenceReference,
        notes: draft.notes,
      );
      await _refresh();
      if (mounted) setState(() => _busyIds.remove(submission.id));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busyIds.remove(submission.id);
        _error = error;
      });
    }
  }

  Future<void> _resolveDispute(
    TrustedReviewSubmission submission,
    String decision,
  ) async {
    final draft = await showDialog<_TrustedReviewDraft>(
      context: context,
      builder: (context) => _TrustedReviewDialog(decision: decision),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _busyIds.add(submission.id);
      _error = null;
    });
    try {
      await widget.presenter.resolveTrustedDispute(
        submissionId: submission.id,
        decision: decision,
        evidenceReference: draft.evidenceReference,
      );
      await _refresh();
      if (mounted) setState(() => _busyIds.remove(submission.id));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busyIds.remove(submission.id);
        _error = error;
      });
    }
  }

  Future<void> _evaluate(TrustedDatasetVersion version) async {
    setState(() {
      _busyIds.add(version.id);
      _error = null;
    });
    try {
      await widget.presenter.evaluateTrustedDatasetVersion(version.id);
      await _refresh();
      if (mounted) setState(() => _busyIds.remove(version.id));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busyIds.remove(version.id);
        _error = error;
      });
    }
  }

  Future<void> _release(TrustedDatasetVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate evaluated dataset?'),
        content: Text(
          'Activate ${version.versionLabel}? The current active version will be retained for rollback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyIds.add(version.id);
      _error = null;
    });
    try {
      await widget.presenter.releaseTrustedDatasetVersion(version.id);
      await _refresh();
      if (mounted) setState(() => _busyIds.remove(version.id));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busyIds.remove(version.id);
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Scam intelligence',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TrustedErrorCard(
              message: 'Could not load or save: $_error',
            ),
          ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                const Text(
                  'Reports are screened for privacy, reviewed by people, and kept out of the live detector until an administrator evaluates and releases a dataset.',
                  style: TextStyle(color: Color(0xFFC4B5FD)),
                ),
                const SizedBox(height: 18),
                _sectionTitle('Your submitted examples'),
                if (_myExamples.isEmpty)
                  const _TrustedEmptyState(
                    text: 'You have not submitted any examples.',
                  )
                else
                  for (final example in _myExamples)
                    _MyExampleCard(example: example),
                if (widget.isModerator) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('Moderator review queue'),
                  if (_queue.isEmpty)
                    const _TrustedEmptyState(
                      text: 'There are no examples waiting for review.',
                    )
                  else
                    for (final submission in _queue)
                      _ReviewSubmissionCard(
                        submission: submission,
                        busy: _busyIds.contains(submission.id),
                        canReview:
                            submission.reporterId != widget.currentUserId &&
                            !submission.reviewedByCurrentUser &&
                            submission.status != 'disputed',
                        canResolveDispute:
                            widget.isAdmin && submission.status == 'disputed',
                        onReview: (decision) =>
                            _submitReview(submission, decision),
                        onResolveDispute: (decision) =>
                            _resolveDispute(submission, decision),
                      ),
                ],
                if (widget.isAdmin) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('Dataset evaluation and release'),
                  if (_versions.isEmpty)
                    const _TrustedEmptyState(
                      text: 'Verified examples will appear here as staged versions.',
                    )
                  else
                    for (final version in _versions)
                      _DatasetVersionCard(
                        version: version,
                        busy: _busyIds.contains(version.id),
                        onEvaluate: () => _evaluate(version),
                        onRelease: () => _release(version),
                      ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

class _MyExampleCard extends StatelessWidget {
  const _MyExampleCard({required this.example});

  final TrustedExampleStatus example;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.fact_check_outlined),
      title: Text('${example.contentType} · ${example.submittedLabel}'),
      subtitle: Text(
        [
          'Status: ${example.status.replaceAll('_', ' ')}',
          ...?(example.statusNote == null ? null : [example.statusNote!]),
        ].join('\n'),
      ),
      isThreeLine: example.statusNote != null,
    ),
  );
}

class _ReviewSubmissionCard extends StatelessWidget {
  const _ReviewSubmissionCard({
    required this.submission,
    required this.busy,
    required this.canReview,
    required this.canResolveDispute,
    required this.onReview,
    required this.onResolveDispute,
  });

  final TrustedReviewSubmission submission;
  final bool busy;
  final bool canReview;
  final bool canResolveDispute;
  final ValueChanged<String> onReview;
  final ValueChanged<String> onResolveDispute;

  @override
  Widget build(BuildContext context) {
    final categories = submission.screeningCategories.isEmpty
        ? 'No automated pattern categories matched.'
        : submission.screeningCategories.join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${submission.contentType} · reporter label: ${submission.submittedLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Automated screen: ${submission.screeningRiskLevel ?? 'unknown'} · $categories',
              style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12),
            ),
            const SizedBox(height: 8),
            SelectableText(submission.content),
            ...?(submission.statusNote == null
                ? null
                : <Widget>[
                    const SizedBox(height: 6),
                    Text(
                      submission.statusNote!,
                      style: const TextStyle(color: Color(0xFFFFC46B)),
                    ),
                  ]),
            if (submission.reviews.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${submission.reviews.length} prior review(s): '
                '${submission.reviews.map((review) => review.decision.replaceAll('_', ' ')).join(', ')}',
                style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12),
              ),
            ],
            if (canReview) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : () => onReview('verified_scam'),
                    child: const Text('Verify scam'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onReview('verified_legitimate'),
                    child: const Text('Verify legitimate'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => onReview('rejected'),
                    child: const Text('Reject'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => onReview('disputed'),
                    child: const Text('Dispute'),
                  ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              const Text(
                'Both scam and legitimate labels require two distinct moderators.',
                style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 11),
              ),
            ] else if (canResolveDispute) ...[
              const SizedBox(height: 10),
              const Text(
                'Resolve this conflict with an administrator override and independent evidence.',
                style: TextStyle(color: Color(0xFFFFC46B), fontSize: 12),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onResolveDispute('verified_scam'),
                    child: const Text('Admin resolve as scam'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onResolveDispute('verified_legitimate'),
                    child: const Text('Admin resolve as legitimate'),
                  ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
            ] else
              const Text(
                'You submitted or already reviewed this example; you cannot review it again.',
                style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _DatasetVersionCard extends StatelessWidget {
  const _DatasetVersionCard({
    required this.version,
    required this.busy,
    required this.onEvaluate,
    required this.onRelease,
  });

  final TrustedDatasetVersion version;
  final bool busy;
  final VoidCallback onEvaluate;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final rawMetrics = version.evaluationMetrics['metrics'];
    final metrics = rawMetrics is Map
        ? Map<String, dynamic>.from(rawMetrics)
        : const <String, dynamic>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              version.versionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${version.exampleCount} verified example(s) · ${version.evaluationStatus} · ${version.releaseStatus}',
              style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12),
            ),
            if (metrics.isNotEmpty)
              Text(
                'Accuracy ${metrics['accuracy'] ?? '-'} · precision ${metrics['precision'] ?? '-'} · recall ${metrics['recall'] ?? '-'} · false-positive rate ${metrics['false_positive_rate'] ?? '-'}',
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onEvaluate,
                  child: const Text('Evaluate'),
                ),
                if (version.evaluationStatus == 'passed' &&
                    version.releaseStatus != 'active')
                  FilledButton(
                    onPressed: busy ? null : onRelease,
                    child: const Text('Activate / roll back'),
                  ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _TrustedReviewDraft {
  const _TrustedReviewDraft({
    required this.method,
    required this.evidenceReference,
    required this.notes,
  });

  final String method;
  final String evidenceReference;
  final String? notes;
}

class _TrustedReviewDialog extends StatefulWidget {
  const _TrustedReviewDialog({required this.decision});

  final String decision;

  @override
  State<_TrustedReviewDialog> createState() => _TrustedReviewDialogState();
}

class _TrustedReviewDialogState extends State<_TrustedReviewDialog> {
  final _evidenceController = TextEditingController();
  final _notesController = TextEditingController();
  String _method = 'official_source';
  String? _error;

  @override
  void dispose() {
    _evidenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Record ${widget.decision.replaceAll('_', ' ')}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cite a trustworthy source or explain the independent verification basis. Automated screening never counts as verification.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Verification method'),
            items: const [
              DropdownMenuItem(
                value: 'official_source',
                child: Text('Official source'),
              ),
              DropdownMenuItem(
                value: 'direct_contact',
                child: Text('Direct contact'),
              ),
              DropdownMenuItem(
                value: 'law_enforcement',
                child: Text('Law enforcement'),
              ),
              DropdownMenuItem(
                value: 'independent_fact_check',
                child: Text('Independent fact-check'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _method = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _evidenceController,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Evidence reference / verification basis',
            ),
          ),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Moderator notes (optional)',
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final evidence = _evidenceController.text.trim();
          if (evidence.length < 12) {
            setState(
              () => _error = 'Provide at least 12 characters of evidence.',
            );
            return;
          }
          Navigator.pop(
            context,
            _TrustedReviewDraft(
              method: _method,
              evidenceReference: evidence,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          );
        },
        child: const Text('Submit review'),
      ),
    ],
  );
}

class _TrustedEmptyState extends StatelessWidget {
  const _TrustedEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(text, style: const TextStyle(color: Color(0xFFC4B5FD))),
    ),
  );
}

class _TrustedErrorCard extends StatelessWidget {
  const _TrustedErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF3B2326),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, style: const TextStyle(color: Color(0xFFFFB6B6))),
    ),
  );
}
