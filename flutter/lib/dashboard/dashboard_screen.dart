import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/permissions/permission_service.dart';
import '../core/permissions/message_notification_service.dart';
import 'account_security_dialog.dart';
import 'dashboard_repository.dart';
import 'heuristic_scanner.dart';
import 'safety_assistant_page.dart';
import 'screenshot_text_extractor.dart';
import 'trusted_intelligence_page.dart';

typedef _ScanAnalysisOptions = ({bool useAi, bool useUrlReputation});
typedef _NotificationReviewSelection = ({
  PendingMessageNotification notification,
  bool shouldScan,
});

const _dashboardInitialLoadTimeout = Duration(seconds: 20);
const _dashboardTabTransitionDuration = Duration(milliseconds: 260);
const _dashboardStatisticTransitionDuration = Duration(milliseconds: 180);
const _notificationRetentionOptions = [1, 7, 30];

class _AlertFeed {
  const _AlertFeed({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
  });

  final List<SecurityAlert> alerts;
  final bool isLoading;
  final Object? error;
}

Stream<T> _timeoutBeforeFirstEvent<T>(Stream<T> source, Duration timeout) {
  return Stream<T>.multi((controller) {
    var receivedFirstEvent = false;
    final timer = Timer(timeout, () {
      if (!receivedFirstEvent) {
        controller.addError(
          TimeoutException('The initial dashboard stream event timed out.'),
        );
      }
    });
    final subscription = source.listen(
      (event) {
        if (!receivedFirstEvent) {
          receivedFirstEvent = true;
          timer.cancel();
        }
        controller.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!receivedFirstEvent) {
          receivedFirstEvent = true;
          timer.cancel();
        }
        controller.addError(error, stackTrace);
      },
      onDone: () {
        if (!receivedFirstEvent) {
          receivedFirstEvent = true;
          timer.cancel();
        }
        controller.close();
      },
    );
    controller.onCancel = () {
      timer.cancel();
      return subscription.cancel();
    };
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.avatarPath,
    this.userId,
    this.isTrustedModerator = false,
    this.isTrustedAdmin = false,
    required this.onSignOut,
    required this.repository,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String? avatarPath;
  final String? userId;
  final bool isTrustedModerator;
  final bool isTrustedAdmin;
  final Future<void> Function() onSignOut;
  final DashboardRepository repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

String _analysisStatusLabel(String value) {
  return switch (value) {
    'completed' => 'completed',
    'partial' => 'partially completed',
    'not_applicable' => 'not applicable',
    'not_requested' || 'disabled' => 'disabled',
    'not_configured' => 'not configured',
    'timeout' => 'timed out',
    'error' || 'failed' => 'analysis failed',
    'available' => 'available',
    'unavailable' => 'unavailable',
    'rate_limited' => 'rate limited',
    'skipped_verified_threat' =>
      'skipped because verified threat intelligence is sufficient',
    _ => 'unavailable',
  };
}

String _classificationLabel(ScanClassification value) {
  return switch (value) {
    ScanClassification.safe => 'SAFE',
    ScanClassification.suspicious => 'SUSPICIOUS',
    ScanClassification.scam => 'MALICIOUS',
    ScanClassification.unknown => 'UNKNOWN',
  };
}

String _riskLabelForResult(ScanRiskLevel value) {
  return switch (value) {
    ScanRiskLevel.low => 'Low',
    ScanRiskLevel.medium => 'Medium',
    ScanRiskLevel.high => 'High',
    ScanRiskLevel.critical => 'Critical',
    ScanRiskLevel.unknown => 'Undetermined',
  };
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _scanHistoryPageSize = 50;
  static const _feedbackScanThreshold = 5;
  static const _permissionService = PermissionService();
  static const _messageNotificationService = MessageNotificationService();
  late final _pendingNotificationQueue = PendingMessageNotificationQueue(
    remove: _messageNotificationService.remove,
    markCompleted: _messageNotificationService.markCompleted,
  );

  int _selectedTab = 0;
  int? _programmaticPageTarget;
  final PageController _pageController = PageController();
  final ValueNotifier<_AlertFeed> _alertFeed = ValueNotifier(
    const _AlertFeed(isLoading: true),
  );
  final ValueNotifier<int> _historySection = ValueNotifier(0);
  late Future<DashboardSummary> _summaryFuture;
  StreamSubscription<List<SecurityAlert>>? _alertsSubscription;
  int _alertsRequestId = 0;
  FamilyGroup? _family;
  Object? _familyError;
  bool _familyLoading = true;
  PrivacySettings? _privacySettings;
  Object? _privacySettingsError;
  bool _privacySettingsLoading = true;
  bool _privacySettingsSaving = false;
  List<ScanHistoryEntry> _scanHistory = const [];
  Object? _scanHistoryError;
  bool _scanHistoryLoading = true;
  bool _scanHistoryHasMore = false;
  int _scanHistoryRequestId = 0;
  final Set<String> _readAlertIds = {};
  late String _profileEmail;
  late String _profileFirstName;
  late String _profileLastName;
  String? _profileAvatarPath;
  String? _profileAvatarUrl;
  String? _profileAvatarError;

  @override
  void initState() {
    super.initState();
    _profileEmail = widget.email;
    _profileFirstName = widget.firstName;
    _profileLastName = widget.lastName;
    _profileAvatarPath = widget.avatarPath;
    _summaryFuture = _loadSummary();
    _refreshAlerts();
    _refreshFamily();
    _refreshPrivacySettings();
    _refreshScanHistory();
    if (_profileAvatarPath != null) unawaited(_refreshProfilePhoto());
  }

  Future<void> _showPermissionCenter() async {
    if (!mounted) return;

    final supportsAndroidNotifications =
        _permissionService.supportsAndroidNotifications;
    final notificationStatus = await _permissionService.notificationStatus();
    var messageAccessEnabled = false;
    var monitoringConsent = false;
    var retentionDays = 7;
    var pendingMessages = const <PendingMessageNotification>[];
    if (supportsAndroidNotifications) {
      try {
        messageAccessEnabled = await _messageNotificationService.isEnabled();
        monitoringConsent = await _messageNotificationService
            .hasMonitoringConsent();
        retentionDays = await _messageNotificationService.retentionDays();
        pendingMessages = await _messageNotificationService.pending();
      } on PlatformException {
        if (mounted) {
          await _handleUnreadableNotificationStorage();
        }
        return;
      } on StateError {
        if (mounted) _showMessage('Notification settings could not be loaded.');
        return;
      }
    }
    if (!mounted) return;

    var selectedRetentionDays = retentionDays;
    final allowNotifications = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Permission control'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose which Android permission Cyvora can use. '
                  'You can change this later in Android settings.',
                ),
                const SizedBox(height: 16),
                _PermissionRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Family notifications',
                  description:
                      'Receive alerts when a shared family report needs '
                      'attention. Android notification access is optional.',
                ),
                if (supportsAndroidNotifications) ...[
                  const SizedBox(height: 10),
                  _PermissionRow(
                    icon: Icons.message_outlined,
                    title: 'Message notification scanning',
                    description: messageAccessEnabled && monitoringConsent
                        ? 'On with your consent. Previews are encrypted on this '
                              'device and expire after $selectedRetentionDays days. '
                              'Only messages you select are sent for analysis.'
                        : messageAccessEnabled
                        ? 'Android access is enabled, but Cyvora monitoring is '
                              'off until you consent.'
                        : 'Off. Cyvora does not collect message notifications '
                              'without your consent and Android access.',
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(child: Text('Keep previews for')),
                      DropdownButton<int>(
                        key: const Key('notification-retention-days'),
                        value: selectedRetentionDays,
                        items: _notificationRetentionOptions
                            .map(
                              (days) => DropdownMenuItem<int>(
                                value: days,
                                child: Text(
                                  '$days ${days == 1 ? 'day' : 'days'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (days) async {
                          if (days == null) return;
                          try {
                            await _messageNotificationService.setRetentionDays(
                              days,
                            );
                            final updatedPending =
                                await _messageNotificationService.pending();
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                selectedRetentionDays = days;
                                pendingMessages = updatedPending;
                              });
                            }
                          } on PlatformException {
                            if (dialogContext.mounted) {
                              _showMessage(
                                'Could not update notification retention.',
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const Text(
                    'Pending previews are encrypted locally, removed '
                    'automatically after this period, and can be deleted sooner.',
                    style: TextStyle(fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      if (!monitoringConsent) {
                        final consent = await _confirmMessageMonitoringConsent(
                          selectedRetentionDays,
                        );
                        if (consent != true || !dialogContext.mounted) return;
                        try {
                          await _messageNotificationService
                              .setMonitoringConsent(true);
                          setDialogState(() => monitoringConsent = true);
                        } on PlatformException {
                          if (dialogContext.mounted) {
                            _showMessage(
                              'Could not save your monitoring consent.',
                            );
                          }
                          return;
                        }
                      }
                      try {
                        await _messageNotificationService.openSettings();
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(false);
                        }
                      } on PlatformException {
                        if (dialogContext.mounted) {
                          _showMessage(
                            'Android notification access settings could not be opened.',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(
                      monitoringConsent
                          ? 'Manage notification access'
                          : 'Review consent and enable',
                    ),
                  ),
                  if (monitoringConsent)
                    TextButton(
                      onPressed: () async {
                        final disable =
                            await _confirmDisableMessageMonitoring();
                        if (disable != true || !dialogContext.mounted) return;
                        try {
                          await _messageNotificationService
                              .setMonitoringConsent(false);
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              monitoringConsent = false;
                              pendingMessages = const [];
                            });
                          }
                        } on PlatformException {
                          if (dialogContext.mounted) {
                            _showMessage(
                              'Could not disable message monitoring.',
                            );
                          }
                        }
                      },
                      child: const Text('Disable Cyvora monitoring'),
                    ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Photos and screenshots use the system picker and do not '
                  'require broad storage access. Web and iOS builds use their '
                  'platform notification settings.',
                  style: TextStyle(fontSize: 12),
                ),
                if (!supportsAndroidNotifications) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Android notification permission is not available on this '
                    'platform build. Family alerts remain available in the app.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (notificationStatus?.isPermanentlyDenied == true)
              TextButton(
                onPressed: () async {
                  await _permissionService.openSettings();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('Open settings'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                notificationStatus?.isGranted == true
                    ? 'Keep enabled'
                    : 'Deny all',
              ),
            ),
            if (pendingMessages.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  unawaited(_reviewPendingMessageNotifications());
                },
                child: Text('Review messages (${pendingMessages.length})'),
              ),
            if (pendingMessages.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  unawaited(_confirmClearPendingNotifications());
                },
                child: const Text('Clear pending'),
              ),
            FilledButton(
              onPressed:
                  supportsAndroidNotifications &&
                      notificationStatus?.isGranted != true &&
                      notificationStatus?.isPermanentlyDenied != true
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: Text(
                notificationStatus?.isGranted == true
                    ? 'Already enabled'
                    : 'Allow notifications',
              ),
            ),
          ],
        ),
      ),
    );
    if (allowNotifications != true ||
        !supportsAndroidNotifications ||
        !mounted) {
      return;
    }

    final status = await _permissionService.requestNotifications();
    if (!mounted || status?.isGranted == true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications remain disabled. You can enable them in Android settings.',
        ),
      ),
    );
  }

  Future<bool?> _confirmMessageMonitoringConsent(int retentionDays) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable message monitoring?'),
        content: Text(
          'Cyvora will read notification titles and previews from other apps '
          'only while Android notification access and your Cyvora consent are '
          'enabled. Previews are encrypted on this device and expire after '
          '$retentionDays days. Only messages you choose to scan are sent to '
          'the analysis service. You can turn monitoring off or delete queued '
          'messages at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I agree, continue'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDisableMessageMonitoring() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable message monitoring?'),
        content: const Text(
          'Cyvora will stop collecting notification previews and delete any '
          'pending previews stored on this device. Existing scan history is '
          'not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep enabled'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disable and delete previews'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearPendingNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pending message previews?'),
        content: const Text(
          'This permanently deletes all queued notification previews from '
          'this device. It does not delete scan history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _messageNotificationService.clearPending();
      if (mounted) _showMessage('Pending message previews were deleted.');
    } on PlatformException {
      if (mounted) _showMessage('Could not delete pending message previews.');
    }
  }

  Future<void> _handleUnreadableNotificationStorage() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification previews unavailable'),
        content: const Text(
          'Cyvora could not securely open the stored previews. This can happen '
          'if the device encryption key is unavailable. You can delete the '
          'unreadable local data; this does not delete scan history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep data'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete unreadable data'),
          ),
        ],
      ),
    );
    if (clear != true) return;
    try {
      await _messageNotificationService.clearPending();
      if (mounted) {
        _showMessage('Unreadable notification data was deleted.');
      }
    } on PlatformException {
      if (mounted) {
        _showMessage('Could not delete unreadable notification data.');
      }
    }
  }

  Future<void> _reviewPendingMessageNotifications() async {
    late final List<PendingMessageNotification> pending;
    try {
      pending = await _messageNotificationService.pending();
    } on PlatformException {
      if (mounted) _showMessage('Secure notification storage is unavailable.');
      return;
    }
    if (!mounted || pending.isEmpty) return;

    final selection = await showDialog<_NotificationReviewSelection>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review detected messages'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: pending.length,
            separatorBuilder: (_, _) => const Divider(height: 18),
            itemBuilder: (context, index) {
              final item = pending[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title.isEmpty ? item.packageName : item.title),
                subtitle: Text(
                  item.text.isEmpty
                      ? 'No message preview was provided.'
                      : item.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete this preview',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () =>
                          Navigator.of(context)
                              .pop((notification: item, shouldScan: false)),
                    ),
                    IconButton(
                      tooltip: 'Scan this message',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () =>
                          Navigator.of(context)
                              .pop((notification: item, shouldScan: true)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (!mounted || selection == null) return;

    if (!selection.shouldScan) {
      try {
        await _messageNotificationService.remove(selection.notification.id);
        if (mounted) _showMessage('Pending message preview deleted.');
      } on PlatformException {
        if (mounted) {
          _showMessage('Could not delete the pending message preview.');
        }
      }
      return;
    }

    try {
      final outcome = await _pendingNotificationQueue.scan(
        selection.notification,
        (content) => _analyze('message', content, showFailureMessage: false),
      );
      if (!mounted) return;
      switch (outcome) {
        case NotificationScanOutcome.completed:
          break;
        case NotificationScanOutcome.failed:
          _showNotificationRetryMessage(
            'The notification was kept because analysis failed.',
          );
        case NotificationScanOutcome.alreadyProcessing:
          _showMessage('This notification is already being analyzed.');
        case NotificationScanOutcome.noContent:
          _showMessage('No message text was available to scan.');
      }
    } on PlatformException {
      if (mounted) {
        _showNotificationRetryMessage(
          'The scan completed, but the notification queue could not be updated.',
        );
      }
    }
  }

  void _showNotificationRetryMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$message You can retry from the pending messages.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_reviewPendingMessageNotifications()),
          ),
        ),
      );
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email != oldWidget.email) _profileEmail = widget.email;
    if (widget.firstName != oldWidget.firstName) {
      _profileFirstName = widget.firstName;
    }
    if (widget.lastName != oldWidget.lastName) {
      _profileLastName = widget.lastName;
    }
    if (widget.avatarPath != oldWidget.avatarPath) {
      _profileAvatarPath = widget.avatarPath;
      _profileAvatarUrl = null;
      if (widget.avatarPath != null) unawaited(_refreshProfilePhoto());
    }
  }

  @override
  void dispose() {
    _alertsRequestId++;
    final subscription = _alertsSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _alertFeed.dispose();
    _historySection.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= 4 || index == _selectedTab) return;
    setState(() => _selectedTab = index);
    if (index == 3 && _profileAvatarPath != null) {
      unawaited(_refreshProfilePhoto());
    }
    if (!_pageController.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) {
      _programmaticPageTarget = index;
      _pageController.jumpToPage(index);
      return;
    }
    _programmaticPageTarget = index;
    unawaited(
      _pageController
          .animateToPage(
            index,
            duration: _dashboardTabTransitionDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (!mounted) return;
            if (_programmaticPageTarget == index) {
              _programmaticPageTarget = null;
            }
            final currentPage = _pageController.page?.round();
            if (currentPage != null && currentPage != _selectedTab) {
              setState(() => _selectedTab = currentPage);
            }
          }),
    );
  }

  void _onTabPageChanged(int index) {
    final target = _programmaticPageTarget;
    if (target != null) {
      if (index == target) _programmaticPageTarget = null;
      return;
    }
    if (index != _selectedTab) setState(() => _selectedTab = index);
  }

  void _openHistorySection(int section) {
    _historySection.value = section;
    _selectTab(2);
  }

  void _refreshSummary() {
    setState(() {
      _summaryFuture = _loadSummary();
    });
  }

  void _refreshAlerts() {
    final requestId = ++_alertsRequestId;
    final previous = _alertFeed.value;
    _alertFeed.value = _AlertFeed(alerts: previous.alerts, isLoading: true);
    final previousSubscription = _alertsSubscription;
    _alertsSubscription = null;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    _alertsSubscription = _watchAlerts().listen(
      (alerts) {
        if (!mounted || requestId != _alertsRequestId) return;
        _alertFeed.value = _AlertFeed(alerts: _withReadState(alerts));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || requestId != _alertsRequestId) return;
        _alertFeed.value = _AlertFeed(
          alerts: _alertFeed.value.alerts,
          error: error,
        );
      },
      onDone: () {
        if (!mounted || requestId != _alertsRequestId) return;
        final current = _alertFeed.value;
        _alertFeed.value = _AlertFeed(
          alerts: current.alerts,
          error: current.error,
        );
      },
    );
  }

  Future<DashboardSummary> _loadSummary() {
    return widget.repository.loadSummary().timeout(
      _dashboardInitialLoadTimeout,
      onTimeout: () =>
          throw TimeoutException('The dashboard summary request timed out.'),
    );
  }

  Stream<List<SecurityAlert>> _watchAlerts() {
    return _timeoutBeforeFirstEvent(
      widget.repository.watchAlerts(),
      _dashboardInitialLoadTimeout,
    );
  }

  List<SecurityAlert> _withReadState(Iterable<SecurityAlert> alerts) {
    return List<SecurityAlert>.unmodifiable(
      alerts.map(
        (alert) => SecurityAlert(
          id: alert.id,
          title: alert.title,
          detail: alert.detail,
          severity: alert.severity,
          createdAt: alert.createdAt,
          isRead: alert.isRead || _readAlertIds.contains(alert.id),
          familyId: alert.familyId,
        ),
      ),
    );
  }

  Future<void> _refreshFamily() async {
    setState(() {
      _familyLoading = true;
      _familyError = null;
    });
    try {
      final family = await widget.repository.loadFamily();
      if (mounted) setState(() => _family = family);
    } on Exception catch (error) {
      if (mounted) setState(() => _familyError = error);
    } on StateError catch (error) {
      if (mounted) setState(() => _familyError = error);
    } finally {
      if (mounted) setState(() => _familyLoading = false);
    }
  }

  Future<void> _refreshPrivacySettings() async {
    setState(() {
      _privacySettingsLoading = true;
      _privacySettingsError = null;
    });
    try {
      final settings = await widget.repository.loadPrivacySettings();
      if (mounted) setState(() => _privacySettings = settings);
    } on Exception catch (error) {
      if (mounted) setState(() => _privacySettingsError = error);
    } on StateError catch (error) {
      if (mounted) setState(() => _privacySettingsError = error);
    } finally {
      if (mounted) setState(() => _privacySettingsLoading = false);
    }
  }

  Future<void> _updatePrivacySettings(PrivacySettings settings) async {
    if (_privacySettingsSaving) return;
    setState(() => _privacySettingsSaving = true);
    try {
      await widget.repository.updatePrivacySettings(settings);
      if (!mounted) return;
      setState(() => _privacySettings = settings);
      _showMessage('Privacy preferences saved.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not save privacy preferences: $error');
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _privacySettingsSaving = false);
    }
  }

  Future<void> _saveProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    final emailChanged =
        normalizedEmail.toLowerCase() != _profileEmail.trim().toLowerCase();
    await widget.repository.updateAccountProfile(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: normalizedEmail,
    );
    if (!mounted) return;
    setState(() {
      _profileFirstName = firstName.trim();
      _profileLastName = lastName.trim();
      if (!emailChanged) _profileEmail = normalizedEmail;
    });
    _showMessage(
      emailChanged
          ? 'Profile updated. Confirm your new email from the verification message to finish changing it.'
          : 'Profile information updated.',
    );
  }

  Future<String> _uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final userId = widget.userId;
    if (userId == null) {
      throw StateError('Sign in before updating your profile photo.');
    }
    final url = await widget.repository.uploadProfilePhoto(
      bytes: bytes,
      contentType: contentType,
    );
    if (!mounted) return url;
    setState(() {
      _profileAvatarPath = '$userId/avatar';
      _profileAvatarUrl = url;
      _profileAvatarError = null;
    });
    _showMessage('Profile photo updated.');
    unawaited(_refreshFamily());
    return url;
  }

  Future<void> _refreshProfilePhoto() async {
    final avatarPath = _profileAvatarPath;
    if (avatarPath == null) return;
    try {
      final url = await widget.repository.loadProfilePhotoUrl(avatarPath);
      if (mounted && avatarPath == _profileAvatarPath) {
        setState(() {
          _profileAvatarUrl = url;
          _profileAvatarError = null;
        });
      }
    } on Exception catch (error) {
      if (mounted && avatarPath == _profileAvatarPath) {
        setState(() => _profileAvatarError = error.toString());
      }
    } on StateError catch (error) {
      if (mounted && avatarPath == _profileAvatarPath) {
        setState(() => _profileAvatarError = error.message);
      }
    }
  }

  Future<void> _refreshScanHistory() async {
    final requestId = ++_scanHistoryRequestId;
    setState(() {
      _scanHistoryLoading = true;
      _scanHistoryError = null;
    });
    try {
      final entries = await widget.repository.loadScanHistory(
        offset: 0,
        limit: _scanHistoryPageSize,
      );
      if (!mounted || requestId != _scanHistoryRequestId) return;
      setState(() {
        _scanHistory = entries;
        _scanHistoryHasMore = entries.length == _scanHistoryPageSize;
      });
    } on Exception catch (error) {
      if (mounted && requestId == _scanHistoryRequestId) {
        setState(() => _scanHistoryError = error);
      }
    } on StateError catch (error) {
      if (mounted && requestId == _scanHistoryRequestId) {
        setState(() => _scanHistoryError = error);
      }
    } finally {
      if (mounted && requestId == _scanHistoryRequestId) {
        setState(() => _scanHistoryLoading = false);
      }
    }
  }

  Future<void> _loadMoreScanHistory() async {
    if (_scanHistoryLoading || !_scanHistoryHasMore) return;
    final requestId = _scanHistoryRequestId;
    setState(() {
      _scanHistoryLoading = true;
      _scanHistoryError = null;
    });
    try {
      final entries = await widget.repository.loadScanHistory(
        offset: _scanHistory.length,
        limit: _scanHistoryPageSize,
      );
      if (!mounted || requestId != _scanHistoryRequestId) return;
      setState(() {
        _scanHistory = [..._scanHistory, ...entries];
        _scanHistoryHasMore = entries.length == _scanHistoryPageSize;
      });
    } on Exception catch (error) {
      if (mounted && requestId == _scanHistoryRequestId) {
        setState(() => _scanHistoryError = error);
      }
    } on StateError catch (error) {
      if (mounted && requestId == _scanHistoryRequestId) {
        setState(() => _scanHistoryError = error);
      }
    } finally {
      if (mounted && requestId == _scanHistoryRequestId) {
        setState(() => _scanHistoryLoading = false);
      }
    }
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    required String successMessage,
    bool refreshFamily = false,
    bool refreshSummary = false,
    bool refreshScanHistory = false,
  }) async {
    try {
      await action();
      if (!mounted) return;
      if (refreshFamily) {
        await _refreshFamily();
        if (_familyError != null) {
          _showMessage(
            'Action completed, but family data did not refresh: $_familyError',
          );
          return;
        }
      }
      if (refreshSummary) _refreshSummary();
      if (refreshScanHistory) {
        await _refreshScanHistory();
        if (_scanHistoryError != null) {
          _showMessage(
            'Action completed, but scan history did not refresh: '
            '$_scanHistoryError',
          );
          return;
        }
      }
      if (!mounted) return;
      _showMessage(successMessage);
    } on Exception catch (error) {
      if (mounted) _showMessage(_mutationErrorMessage(error));
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  String _mutationErrorMessage(Exception error) {
    return 'Could not complete the action: $error';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _scanFunctionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (error.status == 0) {
      return 'Could not reach the analysis service. Check your connection and try again.';
    }
    return 'The analysis service failed (HTTP ${error.status}). Try an on-device scan or try again later.';
  }

  String _assistantFunctionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (error.status == 0) {
      return 'Could not reach the AI assistant. Check your connection and try again.';
    }
    return 'The AI assistant could not respond (HTTP ${error.status}). Please try again.';
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    required String hint,
    int maxLength = 5000,
    TextInputType keyboardType = TextInputType.multiline,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: title,
        label: label,
        hint: hint,
        maxLength: maxLength,
        keyboardType: keyboardType,
      ),
    );
  }

  Future<void> _scanText(String type) async {
    final input = await _promptForText(
      title: _scanTitle(type),
      label: type == 'url' ? 'Website address' : 'Message or extracted text',
      hint: type == 'url'
          ? 'example.com or https://example.com'
          : 'Paste the text you want to check',
      maxLength: type == 'url' ? 2048 : 5000,
      keyboardType: type == 'url' ? TextInputType.url : TextInputType.multiline,
    );
    if (input == null || input.isEmpty || !mounted) return;
    final options = await _chooseScanAnalysis(type);
    if (!mounted || options == null) return;
    await _analyze(
      type,
      input,
      useAi: options.useAi,
      useUrlReputation: options.useUrlReputation,
    );
  }

  void _openSafetyAssistant() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SafetyAssistantPage(
            onSendConversation: _chatSafetyAssistant,
            storageKey: widget.userId ?? widget.email.trim().toLowerCase(),
          ),
        ),
      ),
    );
  }

  Future<String> _chatSafetyAssistant(
    List<AssistantChatMessage> messages,
  ) async {
    try {
      return await widget.repository.chatSafetyAssistant(messages);
    } on FunctionException catch (error) {
      throw SafetyAssistantRequestException(
        _assistantFunctionErrorMessage(error),
      );
    } on FormatException catch (error) {
      throw SafetyAssistantRequestException(error.message);
    } on StateError catch (error) {
      throw SafetyAssistantRequestException(error.message);
    } on Exception catch (error) {
      throw SafetyAssistantRequestException(
        'Could not get an AI response: $error',
      );
    }
  }

  Future<_ScanAnalysisOptions?> _chooseScanAnalysis(String type) {
    final contentType = switch (type) {
      'url' => 'URL',
      'screenshot' => 'text extracted from the screenshot',
      _ => 'message text',
    };
    var useUrlReputation = false;
    return showDialog<_ScanAnalysisOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose server analysis'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The $contentType is sent to Cyvora’s secure analysis '
                  'service. Cyvora applies local rules and reviewed indicator '
                  'data. For links, the service may resolve public DNS records '
                  'and perform a TLS handshake; it does not fetch the submitted '
                  'page or follow redirects. '
                  '${type == 'screenshot' ? 'Web OCR downloads its engine and English model on first use. The screenshot stays on this device; only extracted text is sent if you continue. ' : ''}'
                  'Optional AI-provider analysis sends minimized content to '
                  'the primary provider you configured, with at most one '
                  'configured fallback if enabled. Provider terms, '
                  'quotas, and billing vary.',
                ),
                if (type == 'url') ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    key: const Key('scan-url-reputation-consent'),
                    value: useUrlReputation,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Check external URL reputation'),
                    subtitle: const Text(
                      'If selected, the full URL (including its path and query '
                      'values, without its fragment) is sent to every configured '
                      'reputation provider: '
                      'URLhaus, Google Safe Browsing, AlienVault OTX, '
                      'PhishTank, urlscan.io, ThreatFox, VirusTotal, and '
                      'Pulsedive. The '
                      'OpenPhish community feed is checked locally. A private '
                      'urlscan.io scan is submitted. '
                      'Google Safe Browsing is for eligible non-commercial '
                      'use. '
                      'Providers may retain submitted data under their own '
                      'terms; query values can contain private tokens. '
                      'Matches are shown as SUSPICIOUS, not MALICIOUS.',
                    ),
                    onChanged: (value) =>
                        setDialogState(() => useUrlReputation = value ?? false),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Cyvora saves result metadata, not the original message or '
                  'URL. Avoid sending passwords, verification codes, or other '
                  'sensitive information.',
                ),
              ],
            ),
          ),
          actionsOverflowDirection: VerticalDirection.up,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              key: const Key('scan-with-scam-intelligence'),
              onPressed: () => Navigator.pop(context, (
                useAi: false,
                useUrlReputation: useUrlReputation,
              )),
              child: Text(
                useUrlReputation
                    ? 'Cyvora + URL reputation'
                    : 'Cyvora analysis',
              ),
            ),
            FilledButton(
              key: const Key('scan-with-ai'),
              onPressed: () => Navigator.pop(context, (
                useAi: true,
                useUrlReputation: useUrlReputation,
              )),
              child: Text(
                useUrlReputation
                    ? 'Cyvora + AI + URL reputation'
                    : 'Cyvora + AI-provider analysis',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanScreenshot() async {
    try {
      final options = await _chooseScanAnalysis('screenshot');
      if (!mounted || options == null) return;
      final extractedText = await extractScreenshotText();
      if (extractedText == null || !mounted) return;
      if (extractedText.trim().isEmpty) {
        _showMessage('No readable text was found in that screenshot.');
        return;
      }
      await _analyze('screenshot', extractedText, useAi: options.useAi);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not scan that screenshot: $error');
    } on UnsupportedError catch (error) {
      if (mounted) _showMessage(error.message ?? error.toString());
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  String _scanTitle(String type) => switch (type) {
    'url' => 'Scan URL',
    'screenshot' => 'Scan Screenshot',
    _ => 'Scan Message',
  };

  Future<bool> _analyze(
    String type,
    String input, {
    bool useAi = false,
    bool useUrlReputation = false,
    bool showFailureMessage = true,
  }) async {
    var analysisSucceeded = false;
    try {
      final result = await widget.repository.analyzeAndSave(
        type,
        input,
        useAi: useAi,
        useUrlReputation: useUrlReputation,
      );
      analysisSucceeded = true;
      if (!mounted) return true;
      _refreshSummary();
      _refreshScanHistory();
      await _showScanResult(result, scannedContent: input, scanType: type);
      await _recordScanAndMaybeAskForFeedback();
      return true;
    } on FunctionException catch (error) {
      if (mounted && showFailureMessage) {
        _showMessage(_scanFunctionErrorMessage(error));
      }
      return analysisSucceeded;
    } on FormatException catch (error) {
      if (mounted && showFailureMessage) _showMessage(error.message);
      return analysisSucceeded;
    } on Exception catch (error) {
      if (mounted && showFailureMessage) {
        _showMessage('Could not save this scan: $error');
      }
      return analysisSucceeded;
    } on StateError catch (error) {
      if (mounted && showFailureMessage) _showMessage(error.message);
      return analysisSucceeded;
    }
  }

  Future<void> _recordScanAndMaybeAskForFeedback() async {
    final preferences = await SharedPreferences.getInstance();
    final key =
        'cyvora.feedback.scan-count.${Uri.encodeComponent(widget.email)}';
    final count = (preferences.getInt(key) ?? 0) + 1;
    await preferences.setInt(key, count);
    if (count != _feedbackScanThreshold || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help improve Cyvora'),
        content: const Text(
          'You have completed 5 scans. Your feedback helps the Cyvora team '
          'improve scam detection and safety features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _showScanResult(
    ScanResult result, {
    String? title,
    String? scannedContent,
    String? scanType,
  }) {
    final verdictColor = switch (result.classification) {
      ScanClassification.safe => const Color(0xFF34F5AA),
      ScanClassification.suspicious => const Color(0xFFFFC46B),
      ScanClassification.scam => const Color(0xFFFF6969),
      ScanClassification.unknown => const Color(0xFF9BB2C9),
    };
    final threatIntelligenceResults = result.analysisModules
        .where(
          (item) =>
              item['module'] == 'local_indicator_database' ||
              item['module'] == 'community_reports' ||
              item['module'] == 'external_threat_intelligence',
        )
        .toList(growable: false);
    final primaryResults = result.analysisModules
        .where(
          (item) =>
              item['module'] != 'local_indicator_database' &&
              item['module'] != 'community_reports' &&
              item['module'] != 'external_threat_intelligence',
        )
        .toList(growable: false);
    final rawAiSignals = result.aiAnalysis['signals'];
    final aiSignals = rawAiSignals is List
        ? rawAiSignals
              .whereType<String>()
              .map((signal) => signal.trim())
              .where((signal) => signal.isNotEmpty)
              .take(10)
              .toList(growable: false)
        : const <String>[];
    final rawAiActions = result.aiAnalysis['recommended_actions'];
    final aiRecommendedActions = rawAiActions is List
        ? rawAiActions
              .whereType<String>()
              .map((action) => action.trim())
              .where((action) => action.isNotEmpty)
              .take(5)
              .toList(growable: false)
        : const <String>[];
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Analysis result'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultSectionHeading(title: 'Classification verdict'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: verdictColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: verdictColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _classificationLabel(result.classification),
                        style: TextStyle(
                          color: verdictColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.confidence}% classification confidence',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Risk assessment: ${_riskLabelForResult(result.level)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ResultSectionHeading(title: 'Classification explanation'),
                const SizedBox(height: 5),
                Text(result.summary),
                if (result.recommendedActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResultSectionHeading(title: 'Prevention steps'),
                  for (final action in result.recommendedActions)
                    _ResultEvidenceLine(text: action),
                ],
                if (result.ruleAnalysis.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResultSectionHeading(title: 'Rule-based findings'),
                  if (result.ruleAnalysis['score'] is num)
                    Text('Rule score: ${result.ruleAnalysis['score']}'),
                  if (result.ruleAnalysis['version'] is String)
                    Text('Rules version: ${result.ruleAnalysis['version']}'),
                  if (result.ruleAnalysis['categories'] is List)
                    for (final category
                        in (result.ruleAnalysis['categories'] as List)
                            .whereType<String>())
                      _ResultEvidenceLine(text: 'Category: $category'),
                  if (result.ruleAnalysis['indicators'] is List)
                    for (final indicator
                        in (result.ruleAnalysis['indicators'] as List)
                            .whereType<String>())
                      _ResultEvidenceLine(text: indicator),
                ],
                if (result.evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResultSectionHeading(title: 'Supporting evidence'),
                  for (final item in result.evidence)
                    _ResultEvidenceLine(text: item),
                ],
                if (aiRecommendedActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResultSectionHeading(title: 'How to prevent similar scams'),
                  const _ResultEvidenceLine(
                    text: 'AI-generated suggestions are advisory. Verify using an official channel you find independently.',
                  ),
                  for (final action in aiRecommendedActions)
                    _ResultEvidenceLine(text: action),
                ],
                if (result.confidenceReasons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
                    title: const Text('How confidence was calculated'),
                    children: [
                      for (final reason in result.confidenceReasons)
                        _ResultEvidenceLine(text: reason),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _ResultSectionHeading(title: 'Internal analysis modules'),
                if (primaryResults.isEmpty)
                  const _ResultEvidenceLine(
                    text: 'No content-specific checks were required.',
                  )
                else
                  for (final module in primaryResults)
                    _AnalysisModuleTile(result: module),
                if (result.analysisModulesStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ResultSectionHeading(title: 'Analysis check statuses'),
                  for (final status in result.analysisModulesStatus.entries)
                    _ResultEvidenceLine(
                      text:
                          '${status.key.replaceAll('_', ' ')}: ${_analysisStatusLabel(status.value)}',
                    ),
                ],
                if (result.aiAnalysis['status'] is String) ...[
                  if (result.aiAnalysis['status'] == 'available') ...[
                    const SizedBox(height: 12),
                    _ResultSectionHeading(title: 'AI-assisted analysis'),
                    if (result.aiAnalysis['provider'] is String)
                      Text('Provider: ${result.aiAnalysis['provider']}'),
                    const _ResultEvidenceLine(
                      text: 'Advisory context only; Cyvora’s independent checks determine the verdict.',
                    ),
                    if (result.aiAnalysis['summary'] is String) ...[
                      const SizedBox(height: 6),
                      _ResultSectionHeading(title: 'Why it raised a concern'),
                    ],
                    if (result.aiAnalysis['summary'] is String)
                      Text(result.aiAnalysis['summary'] as String),
                    if (aiSignals.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _ResultSectionHeading(title: 'Signals in this scan'),
                      for (final signal in aiSignals)
                        _ResultEvidenceLine(text: signal),
                    ],
                  ] else ...[
                    const SizedBox(height: 8),
                    _ResultEvidenceLine(
                      text:
                          'Optional AI-provider analysis: '
                          '${_analysisStatusLabel(result.aiAnalysis['status'] as String)}'
                          '${result.aiAnalysis['providers_tried'] is List && (result.aiAnalysis['providers_tried'] as List).isNotEmpty ? ' (tried ${(result.aiAnalysis['providers_tried'] as List).join(', ')})' : ''}',
                    ),
                    if (result.aiAnalysis['provider_attempts'] is List)
                      for (final attempt
                          in (result.aiAnalysis['provider_attempts'] as List))
                        if (attempt is Map<String, dynamic> &&
                            attempt['provider'] is String &&
                            attempt['status'] is String)
                          _ResultEvidenceLine(
                            text: _aiProviderAttemptLabel(attempt),
                          ),
                  ],
                ],
                if (threatIntelligenceResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResultSectionHeading(
                    title: 'Local, community, and external threat intelligence',
                  ),
                  for (final module in threatIntelligenceResults)
                    _AnalysisModuleTile(result: module),
                ],
                if (result.analyzedAt != null ||
                    result.engineVersion.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (result.analyzedAt != null)
                    Text(
                      'Last analysis: ${_formatDateTime(result.analyzedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9BB2C9),
                      ),
                    ),
                  if (result.engineVersion.isNotEmpty)
                    Text(
                      'Analysis engine: ${result.engineVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9BB2C9),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (scannedContent != null && scanType != null)
            TextButton.icon(
              key: const Key('report-scan-example'),
              onPressed: () => unawaited(
                _reportScanExample(result, scanType, scannedContent),
              ),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Report result'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportScanExample(
    ScanResult result,
    String contentType,
    String content,
  ) async {
    final label = await showDialog<String>(
      context: context,
      builder: (context) =>
          TrustedExampleFeedbackDialog(contentType: contentType),
    );
    if (label == null) return;
    try {
      final response = await widget.repository.submitTrustedExample(
        contentType: contentType,
        content: content,
        submittedLabel: label,
        scanRecordId: result.recordId,
      );
      if (!mounted) return;
      _showMessage(response.message);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not submit this example: $error');
    }
  }

  Future<void> _openTrustedIntelligence() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 820,
          height: 680,
          child: TrustedIntelligencePage(
            repository: widget.repository,
            isModerator: widget.isTrustedModerator,
            isAdmin: widget.isTrustedAdmin,
            currentUserId: widget.userId,
          ),
        ),
      ),
    );
  }

  Future<void> _openAccountSecurity() {
    return showDialog<void>(
      context: context,
      builder: (context) => AccountSecurityDialog(
        repository: widget.repository,
        email: _profileEmail,
      ),
    );
  }

  Future<void> _createFamily() async {
    final name = await _promptForText(
      title: 'Create a family group',
      label: 'Family group name',
      hint: 'For example, The Santos Family',
      maxLength: 80,
      keyboardType: TextInputType.text,
    );
    if (name == null || name.trim().isEmpty) return;
    await _runMutation(
      () => widget.repository.createFamily(name),
      successMessage: 'Family group created.',
      refreshFamily: true,
    );
  }

  Future<void> _inviteFamilyMember() async {
    final email = await _promptForText(
      title: 'Invite a family member',
      label: 'Invited Cyvora account email',
      hint: 'person@example.com',
      maxLength: 254,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || email.isEmpty) return;
    try {
      final invitation = await widget.repository.createFamilyInvite(email);
      if (!mounted) return;
      await _refreshFamily();
      final familyRefreshIssue = _familyError?.toString();
      await _showManualInvitationCode(
        email,
        invitation.invitationCode,
        familyRefreshIssue: familyRefreshIssue,
      );
    } on Exception catch (error) {
      if (mounted) _showMessage(_mutationErrorMessage(error));
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _showManualInvitationCode(
    String email,
    String code, {
    String? familyRefreshIssue,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('manual-family-invitation'),
        title: const Text('Share this invitation code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this code with $email. They must sign in to Cyvora using '
              'that email address, then enter the code from the Family tab.',
            ),
            if (familyRefreshIssue != null) ...[
              const SizedBox(height: 8),
              Text(
                'Family data did not refresh: $familyRefreshIssue',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            SelectableText(
              code,
              key: const Key('family-invitation-code'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The code expires in 7 days and only works for a Cyvora account '
              'with the invited email address.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            key: const Key('copy-family-invitation-code'),
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: code));
              } on Exception catch (error) {
                if (mounted) {
                  _showMessage(
                    'Could not copy the invitation code: $error. '
                    'You can select and copy it manually.',
                  );
                }
                return;
              }
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Invitation code copied.')),
                );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeFamilyInvite(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel invitation?'),
        content: Text('Cancel the pending invitation sent to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep invitation'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMutation(
      () => widget.repository.revokeFamilyInvite(email),
      successMessage: 'Invitation canceled.',
      refreshFamily: true,
    );
  }

  Future<void> _acceptFamilyInvite() async {
    final token = await _promptForText(
      title: 'Join a family group',
      label: 'Invitation code',
      hint: 'Paste the code shared by the family owner',
      maxLength: 64,
      keyboardType: TextInputType.text,
    );
    if (token == null || token.isEmpty) return;
    await _runMutation(
      () => widget.repository.acceptFamilyInvite(token),
      successMessage: 'You joined the family group.',
      refreshFamily: true,
    );
  }

  Future<void> _removeFamilyMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.isOwner ? 'Leave family group?' : 'Remove member?'),
        content: Text(
          member.isOwner
              ? 'You will leave this family group.'
              : 'Remove ${member.displayName} from this family group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(member.isOwner ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMutation(
      () => widget.repository.removeFamilyMember(member.userId),
      successMessage: member.isOwner
          ? 'You left the family group.'
          : 'Member removed.',
      refreshFamily: true,
    );
  }

  Future<void> _setFamilySharing(bool enabled) async {
    await _runMutation(
      () => widget.repository.setFamilySharing(enabled),
      successMessage: enabled
          ? 'Family report sharing is on.'
          : 'Family report sharing is off.',
      refreshFamily: true,
    );
  }

  Future<void> _confirmDeleteFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete family group?'),
        content: const Text(
          'This removes the group, its memberships, pending invitations, and '
          'family alerts. Existing scam reports become private to their authors.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete group'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMutation(
      widget.repository.deleteFamily,
      successMessage: 'Family group deleted.',
      refreshFamily: true,
    );
  }

  Future<void> _leaveFamily() async {
    await _runMutation(
      widget.repository.leaveFamily,
      successMessage: 'You left the family group.',
      refreshFamily: true,
    );
  }

  Future<void> _reportScam() async {
    final draft = await showDialog<_ReportDraft>(
      context: context,
      builder: (context) =>
          _ReportDialog(canShareWithFamily: _family?.shareReports == true),
    );
    if (draft == null) return;
    await _runMutation(
      () => widget.repository.submitScamReport(
        category: draft.category,
        description: draft.description,
        indicator: draft.indicator,
        shareWithFamily: draft.shareWithFamily,
      ),
      successMessage: draft.indicator == null
          ? 'Scam report saved.'
          : 'Scam report saved. Indicator submitted for review.',
      refreshFamily: draft.shareWithFamily,
      refreshSummary: true,
    );
  }

  Future<void> _markAlertRead(SecurityAlert alert) async {
    try {
      await widget.repository.markAlertRead(alert.id);
      if (!mounted) return;
      _readAlertIds.add(alert.id);
      final current = _alertFeed.value;
      _alertFeed.value = _AlertFeed(
        alerts: _withReadState(current.alerts),
        isLoading: current.isLoading,
        error: current.error,
      );
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not update this alert: $error');
    }
  }

  Future<void> _showAlertDetails(SecurityAlert alert) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(alert.detail, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 16),
              Text(
                'Severity: ${alert.severity.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Received: ${_formatDateTime(alert.createdAt)}'),
              const SizedBox(height: 6),
              Text(
                alert.familyId == null
                    ? 'Source: Personal security alert'
                    : 'Source: Family Protection',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut();
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not sign out: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabAnimationDuration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : _dashboardTabTransitionDuration;
    final pages = [
      _HomeDashboard(
        email: widget.email,
        firstName: _profileFirstName,
        lastName: _profileLastName,
        avatarUrl: _profileAvatarUrl,
        summaryFuture: _summaryFuture,
        alertFeed: _alertFeed,
        summaryError: _refreshSummary,
        retryAlerts: _refreshAlerts,
        onNavigate: _selectTab,
        onViewAlerts: () => _openHistorySection(1),
        onViewHistory: () => _openHistorySection(0),
        onOpenAlert: _showAlertDetails,
        onScan: () => _scanText('message'),
        onScanUrl: () => _scanText('url'),
        onScanScreenshot: _scanScreenshot,
        onReport: _reportScam,
      ),
      _FamilyDashboard(
        family: _family,
        isLoading: _familyLoading,
        error: _familyError,
        alertFeed: _alertFeed,
        onRefresh: _refreshFamily,
        onMarkAlertRead: _markAlertRead,
        onOpenAlert: _showAlertDetails,
        onPermissionCenter: _showPermissionCenter,
        onCreate: _createFamily,
        onInvite: _inviteFamilyMember,
        onRevokeInvite: _revokeFamilyInvite,
        onAcceptInvite: _acceptFamilyInvite,
        onRemoveMember: _removeFamilyMember,
        onSharingChanged: _setFamilySharing,
        onDeleteFamily: _confirmDeleteFamily,
        onLeaveFamily: _leaveFamily,
      ),
      _AlertsPage(
        alertFeed: _alertFeed,
        onMarkRead: _markAlertRead,
        onOpenAlert: _showAlertDetails,
        onRetry: _refreshAlerts,
        selectedSection: _historySection,
        onSectionSelected: (section) => _historySection.value = section,
        scanHistory: _scanHistory,
        scanHistoryLoading: _scanHistoryLoading,
        scanHistoryHasMore: _scanHistoryHasMore,
        scanHistoryError: _scanHistoryError,
        onRefreshScanHistory: _refreshScanHistory,
        onLoadMoreScanHistory: _loadMoreScanHistory,
        onOpenEntry: (entry) => _showScanResult(
          entry.toScanResult(),
          title: '${_scanTypeLabel(entry.scanType)} scan details',
        ),
      ),
      _ProfilePage(
        email: _profileEmail,
        firstName: _profileFirstName,
        lastName: _profileLastName,
        avatarUrl: _profileAvatarUrl,
        avatarError: _profileAvatarError,
        onRefreshAvatar: _refreshProfilePhoto,
        onSignOut: _signOut,
        onUpdateProfile: _saveProfile,
        onUploadProfilePhoto: _uploadProfilePhoto,
        privacySettings: _privacySettings,
        privacySettingsLoading: _privacySettingsLoading,
        privacySettingsError: _privacySettingsError,
        privacySettingsSaving: _privacySettingsSaving,
        onRefreshPrivacySettings: _refreshPrivacySettings,
        onPrivacySettingsChanged: _updatePrivacySettings,
        onOpenTrustedIntelligence: _openTrustedIntelligence,
        onOpenAccountSecurity: _openAccountSecurity,
      ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34E89B),
          brightness: Brightness.dark,
          surface: const Color(0xFF09283D),
          primary: const Color(0xFF34E89B),
          onPrimary: const Color(0xFF03251E),
        ),
        scaffoldBackgroundColor: const Color(0xFF041523),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xFFEAF4FF),
          displayColor: const Color(0xFFEAF4FF),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B2A3D),
          labelStyle: const TextStyle(color: Color(0xFFBDD0E1)),
          hintStyle: const TextStyle(color: Color(0xFF8DA7BB)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF285268)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF285268)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF34E89B), width: 1.5),
          ),
        ),
        dividerColor: const Color(0xFF16445A),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF34E89B)
                : const Color(0xFF9BB2C9),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF1E735D)
                : const Color(0xFF294151),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF041523),
        floatingActionButton: FloatingActionButton(
          key: const Key('ai-assistant'),
          heroTag: 'safety-assistant',
          tooltip: 'Safety Assistant',
          onPressed: _openSafetyAssistant,
          child: const Icon(Icons.smart_toy_outlined),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _DashboardTopBar(
                title: const [
                  'Home',
                  'Family',
                  'History',
                  'Profile',
                ].elementAt(_selectedTab),
                alertFeed: _alertFeed,
                onNotificationsTap: () => _openHistorySection(1),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF061C2D), Color(0xFF041523)],
                    ),
                  ),
                  child: PageView(
                    key: const Key('dashboard-tab-pages'),
                    controller: _pageController,
                    allowImplicitScrolling: true,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: _onTabPageChanged,
                    children: [
                      for (final page in pages)
                        _KeepAliveDashboardPage(child: page),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          key: const Key('dashboard-navigation'),
          animationDuration: tabAnimationDuration,
          selectedIndex: _selectedTab,
          onDestinationSelected: _selectTab,
          height: 72,
          backgroundColor: const Color(0xFF061A2A),
          indicatorColor: const Color(0xFF123D3D),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF34F5AA)
                  : const Color(0xFF9BB2C9),
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            );
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Color(0xFF9BB2C9)),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF34F5AA)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.people_outline_rounded,
                color: Color(0xFF9BB2C9),
              ),
              selectedIcon: Icon(
                Icons.people_rounded,
                color: Color(0xFF34F5AA),
              ),
              label: 'Family',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined, color: Color(0xFF9BB2C9)),
              selectedIcon: Icon(
                Icons.history_rounded,
                color: Color(0xFF34F5AA),
              ),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF9BB2C9),
              ),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: Color(0xFF34F5AA),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.title,
    required this.alertFeed,
    required this.onNotificationsTap,
  });

  final String title;
  final ValueListenable<_AlertFeed> alertFeed;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF061A2A),
        border: Border(bottom: BorderSide(color: Color(0xFF12364B))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0D3B3D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFF34F5AA),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Cyv',
                      style: TextStyle(
                        color: Color(0xFFEAF4FF),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Text(
                      'ora',
                      style: TextStyle(
                        color: Color(0xFF34F5AA),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                if (title != 'Home')
                  Text(
                    title,
                    key: const Key('dashboard-title'),
                    style: const TextStyle(
                      color: Color(0xFF9BB2C9),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<_AlertFeed>(
            valueListenable: alertFeed,
            builder: (context, feed, child) {
              final unreadCount = feed.alerts
                  .where((alert) => !alert.isRead)
                  .length;
              return IconButton(
                key: const Key('dashboard-notifications'),
                tooltip: 'Notifications',
                onPressed: onNotificationsTap,
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: child,
                ),
              );
            },
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFFBDD0E1),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAliveDashboardPage extends StatefulWidget {
  const _KeepAliveDashboardPage({required this.child});

  final Widget child;

  @override
  State<_KeepAliveDashboardPage> createState() =>
      _KeepAliveDashboardPageState();
}

class _KeepAliveDashboardPageState extends State<_KeepAliveDashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class _DashboardAnimatedSwitcher extends StatelessWidget {
  const _DashboardAnimatedSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : _dashboardStatisticTransitionDuration;
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AnimatedStatisticValue extends StatelessWidget {
  const _AnimatedStatisticValue({
    required this.value,
    required this.style,
    this.textAlign,
  });

  final String value;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return _DashboardAnimatedSwitcher(
      child: Text(
        value,
        key: ValueKey(value),
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

class _ResultSectionHeading extends StatelessWidget {
  const _ResultSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}

class _ResultEvidenceLine extends StatelessWidget {
  const _ResultEvidenceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _AnalysisModuleTile extends StatelessWidget {
  const _AnalysisModuleTile({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final module = result['module'] as String;
    final status = result['status'] as String;
    final evidenceKind = result['evidence_kind'] as String;
    final statusColor = evidenceKind == 'confirmed_detection'
        ? const Color(0xFFFF6969)
        : evidenceKind == 'suspicious_signal'
        ? const Color(0xFFFFC46B)
        : evidenceKind == 'no_match'
        ? const Color(0xFF34F5AA)
        : const Color(0xFF9BB2C9);
    final checkedAt = DateTime.parse(result['checked_at'] as String);
    final indicatorType = result['indicator_type'];
    final details = result['details'];
    final providerResults =
        module == 'external_threat_intelligence' &&
            details is Map<String, dynamic> &&
            details['providers'] is List
        ? (details['providers'] as List)
        : const <dynamic>[];
    final moduleLabel = module
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');

    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: const Color(0xFF0B2A3D),
      child: ExpansionTile(
        key: Key(
          'analysis-$module-${result['indicator_type']}-${result['indicator_hash'] ?? ''}',
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(
          indicatorType is String
              ? '$moduleLabel · ${indicatorType.toUpperCase()}'
              : moduleLabel,
        ),
        subtitle: Text(
          '${_analysisResultLabel(evidenceKind)} · '
          '${_analysisStatusLabel(status)}',
          style: TextStyle(color: statusColor),
        ),
        children: [
          _ResultEvidenceLine(
            text: result['indicator_hash'] is String
                ? 'Indicator relevance: exact normalized indicator'
                : 'Indicator relevance: content-level analysis',
          ),
          if (result['category'] is String)
            _ResultEvidenceLine(text: 'Category: ${result['category']}'),
          if (result['error_reason'] is String)
            _ResultEvidenceLine(
              text: 'Unavailable reason: ${result['error_reason']}',
            ),
          if (result['source'] is String)
            _ResultEvidenceLine(text: 'Source: ${result['source']}'),
          for (final item in (result['evidence'] as List).whereType<String>())
            _ResultEvidenceLine(text: item),
          if (details is Map<String, dynamic> && details['status'] is String)
            _ResultEvidenceLine(
              text:
                  'Provider checks: ${_reputationStatusLabel(details['status'] as String)}',
            ),
          for (final item in providerResults)
            if (item is Map<String, dynamic>) ...[
              _ResultEvidenceLine(
                text:
                    '${_providerLabel(item['provider'])}: ${_providerStatusLabel(item['status'])}',
              ),
              if (item['findings'] is List)
                for (final finding
                    in (item['findings'] as List).whereType<String>())
                  _ResultEvidenceLine(text: finding),
              if (item['scan_id'] is String)
                _ResultEvidenceLine(
                  text: 'Private urlscan.io ID: ${item['scan_id']}',
                ),
            ],
          _ResultEvidenceLine(text: 'Checked: ${_formatDate(checkedAt)}'),
        ],
      ),
    );
  }
}

String _providerLabel(Object? value) {
  if (value is! String || value.isEmpty) return 'Provider';
  const labels = {
    'gemini': 'Google Gemini',
    'groq': 'Groq',
    'openrouter': 'OpenRouter',
    'mistral': 'Mistral',
    'cloudflare': 'Cloudflare Workers AI',
    'sambanova': 'SambaNova',
    'cohere': 'Cohere',
    'nvidia': 'NVIDIA',
    'zai': 'Z.AI',
    'huggingface': 'Hugging Face',
  };
  if (labels.containsKey(value)) return labels[value]!;
  return value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _aiProviderAttemptLabel(Map<String, dynamic> attempt) {
  final provider = _providerLabel(attempt['provider']);
  final status = switch (attempt['status']) {
    'available' => 'responded',
    'budget_unconfigured' => 'daily usage limits are not configured',
    'budget_check_failed' => 'daily usage limits could not be checked',
    'global_budget_exhausted' => 'global daily request limit reached',
    'user_budget_exhausted' => 'account daily request limit reached',
    'provider_budget_exhausted' => 'provider daily request limit reached',
    'user_cooldown' => 'please wait before requesting another AI analysis',
    'duplicate_request' => 'duplicate request skipped',
    'concurrency_limited' => 'provider is busy; deterministic analysis used',
    'circuit_open' => 'temporarily disabled after repeated failures',
    'authentication_error' => 'authentication failed',
    'rate_limited' => 'rate limited',
    'billing_required' => 'billing or a paid plan is required',
    'model_not_found' => 'model or endpoint not found; check provider settings',
    'model_retired' => 'model retired; choose a supported model',
    'request_rejected' => 'request rejected; check model and request settings',
    'provider_error' => 'provider unavailable',
    'invalid_response' => 'returned an invalid response',
    'timeout' => 'timed out',
    'network_error' => 'network error',
    _ => 'failed',
  };
  final httpStatus = attempt['http_status'];
  return '$provider: $status${httpStatus is int ? ' (HTTP $httpStatus)' : ''}';
}

String _reputationStatusLabel(String status) {
  return switch (status) {
    'available' => 'completed',
    'partial' => 'partially completed',
    'not_configured' => 'not configured',
    'unavailable' => 'unavailable',
    'not_requested' => 'not requested',
    'skipped_non_public' => 'skipped for a private or reserved destination',
    _ => 'unavailable',
  };
}

String _providerStatusLabel(Object? value) {
  return switch (value) {
    'match' => 'match found',
    'no_match' => 'no match found',
    'not_found' => 'no existing report',
    'unverified' => 'listing not verified',
    'submitted' => 'private scan submitted; processing',
    'not_configured' => 'not configured',
    'unavailable' => 'unavailable',
    'timeout' => 'timed out',
    'rate_limited' => 'rate limited',
    'failed' => 'check failed',
    _ => 'unavailable',
  };
}

String _analysisResultLabel(String evidenceKind) {
  return switch (evidenceKind) {
    'confirmed_detection' => 'Confirmed detection',
    'suspicious_signal' => 'Suspicious signal',
    'no_match' => 'No match found',
    'not_checked' => 'Not checked',
    'analysis_unavailable' => 'Analysis unavailable',
    'analysis_failed' => 'Analysis failed',
    _ => 'Analysis unavailable',
  };
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.summaryFuture,
    required this.alertFeed,
    required this.summaryError,
    required this.retryAlerts,
    required this.onNavigate,
    required this.onViewAlerts,
    required this.onViewHistory,
    required this.onOpenAlert,
    required this.onScan,
    required this.onScanUrl,
    required this.onScanScreenshot,
    required this.onReport,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final Future<DashboardSummary> summaryFuture;
  final ValueListenable<_AlertFeed> alertFeed;
  final VoidCallback summaryError;
  final VoidCallback retryAlerts;
  final ValueChanged<int> onNavigate;
  final VoidCallback onViewAlerts;
  final VoidCallback onViewHistory;
  final Future<void> Function(SecurityAlert) onOpenAlert;
  final VoidCallback onScan;
  final VoidCallback onScanUrl;
  final VoidCallback onScanScreenshot;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final fullName = [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final greetingName = fullName.isNotEmpty
        ? fullName
        : email.split('@').first;
    return _DashboardScroll(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D3042), Color(0xFF082435)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF16445A)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('dashboard-greeting-profile'),
                tooltip: 'Open profile',
                onPressed: () => onNavigate(3),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                icon: _ProfileAvatar(
                  key: const Key('home-profile-avatar'),
                  firstName: firstName,
                  lastName: lastName,
                  email: email,
                  imageUrl: avatarUrl,
                  size: 48,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Color(0xFF65F8BB),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hello, $greetingName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFEAF4FF),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Your scam safety overview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFF9BB2C9), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _ProtectionStatusCard(),
        const SizedBox(height: 12),
        FutureBuilder<DashboardSummary>(
          future: summaryFuture,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.hasError)
                  _ErrorCard(
                    message: 'Could not load today’s scan summary.',
                    onRetry: () async => summaryError(),
                  ),
                if (snapshot.hasError) const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 10.0;
                    final scanValue = summary == null
                        ? '—'
                        : '${summary.scansToday}';
                    final warningValue = summary == null
                        ? '—'
                        : '${summary.warningScansToday}';
                    final noPatternValue = summary == null
                        ? '—'
                        : '${summary.lowRiskScansToday}';

                    if (constraints.maxWidth >= 600) {
                      return Row(
                        children: [
                          Expanded(
                            child: _StatisticCard(
                              title: 'Scans',
                              value: scanValue,
                              icon: Icons.radar_rounded,
                              color: const Color(0xFF27C6F5),
                            ),
                          ),
                          const SizedBox(width: spacing),
                          Expanded(
                            child: _StatisticCard(
                              title: 'Warning signs',
                              value: warningValue,
                              icon: Icons.gpp_good_outlined,
                              color: const Color(0xFFFFB33F),
                            ),
                          ),
                          const SizedBox(width: spacing),
                          Expanded(
                            child: _StatisticCard(
                              title: 'No pattern',
                              value: noPatternValue,
                              icon: Icons.check_circle_outline_rounded,
                              color: const Color(0xFF34F5AA),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _CompactStatisticCard(
                            key: const Key('dashboard-stat-scans'),
                            title: 'Scans',
                            value: scanValue,
                            icon: Icons.radar_rounded,
                            color: const Color(0xFF27C6F5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CompactStatisticCard(
                            key: const Key('dashboard-stat-warnings'),
                            title: 'Warning signs',
                            value: warningValue,
                            icon: Icons.gpp_good_outlined,
                            color: const Color(0xFFFFB33F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CompactStatisticCard(
                            key: const Key('dashboard-stat-no-pattern'),
                            title: 'No pattern',
                            value: noPatternValue,
                            icon: Icons.check_circle_outline_rounded,
                            color: const Color(0xFF34F5AA),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton(
            key: const Key('quick-scan'),
            onPressed: onScan,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF34E89B),
              foregroundColor: const Color(0xFF03251E),
              elevation: 3,
              shadowColor: const Color(0x6634E89B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.center_focus_strong_rounded, size: 23),
                SizedBox(width: 10),
                Text('Quick Scan'),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 21),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<_AlertFeed>(
          valueListenable: alertFeed,
          builder: (context, feed, heading) {
            final Widget content;
            if (feed.error != null) {
              content = KeyedSubtree(
                key: const ValueKey('home-alerts-error'),
                child: _ErrorCard(
                  message: 'Could not load alerts: ${feed.error}',
                  onRetry: () async => retryAlerts(),
                ),
              );
            } else if (feed.isLoading) {
              content = const KeyedSubtree(
                key: ValueKey('home-alerts-loading'),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (feed.alerts.isEmpty) {
              content = const KeyedSubtree(
                key: ValueKey('home-alerts-empty'),
                child: _EmptyStateCard(
                  icon: Icons.notifications_none_rounded,
                  title: 'No security alerts',
                  message: 'New in-app alerts will appear here.',
                ),
              );
            } else {
              content = KeyedSubtree(
                key: ValueKey(
                  feed.alerts.take(3).map((alert) => alert.id).join('|'),
                ),
                child: Column(
                  children: [
                    for (final alert in feed.alerts.take(3))
                      _AlertCard(alert: alert, onOpenAlert: onOpenAlert),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading!,
                const SizedBox(height: 6),
                _DashboardAnimatedSwitcher(child: content),
              ],
            );
          },
          child: _SectionHeading(
            title: 'Recent Security Alerts',
            trailing: TextButton(
              key: const Key('view-all-alerts'),
              onPressed: onViewAlerts,
              child: const Text('View all'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SectionHeading(
          title: 'Quick Tools',
          trailing: TextButton(
            key: const Key('view-scan-history'),
            onPressed: onViewHistory,
            child: const Text('View history'),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            if (constraints.maxWidth <= 0) {
              return const SizedBox.shrink();
            }
            final columns = constraints.maxWidth >= 600
                ? 3
                : constraints.maxWidth >= 220
                ? 2
                : 1;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _QuickToolTile(
                    key: const Key('home-quick-scan-message'),
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Scan\nMessage',
                    onTap: onScan,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _QuickToolTile(
                    key: const Key('home-quick-scan-url'),
                    icon: Icons.link_rounded,
                    title: 'Scan\nURL',
                    onTap: onScanUrl,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _QuickToolTile(
                    key: const Key('home-quick-scan-screenshot'),
                    icon: Icons.image_outlined,
                    title: 'Scan\nScreenshot',
                    onTap: onScanScreenshot,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _QuickToolTile(
                    key: const Key('report-scam'),
                    icon: Icons.flag_outlined,
                    title: 'Report\nScam',
                    onTap: onReport,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 76),
      ],
    );
  }
}

class _ScanHistoryPanel extends StatefulWidget {
  const _ScanHistoryPanel({
    required this.entries,
    required this.isLoading,
    required this.hasMore,
    required this.error,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpenEntry,
  });

  final List<ScanHistoryEntry> entries;
  final bool isLoading;
  final bool hasMore;
  final Object? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final ValueChanged<ScanHistoryEntry> onOpenEntry;

  @override
  State<_ScanHistoryPanel> createState() => _ScanHistoryPanelState();
}

class _ScanHistoryPanelState extends State<_ScanHistoryPanel> {
  final _searchController = TextEditingController();
  String _scanTypeFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final entries = widget.entries
        .where((entry) {
          final matchesType =
              _scanTypeFilter == 'all' || entry.scanType == _scanTypeFilter;
          final searchableText = [
            entry.scanType,
            _riskLabel(entry.riskLevel),
            entry.analysisSummary ?? '',
            ...entry.indicators,
            ...entry.recommendedActions,
            ...entry.evidence,
            ...entry.confidenceReasons,
          ].join(' ').toLowerCase();
          return matchesType &&
              (query.isEmpty || searchableText.contains(query));
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          title: 'Saved scans',
          trailing: Text(
            '${entries.length} ${entries.length == 1 ? 'result' : 'results'}',
            style: const TextStyle(
              color: Color(0xFF8DA7BB),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: Color(0xFF8DA7BB),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Original message and URL text are not saved.',
                style: TextStyle(color: Color(0xFF8DA7BB), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF082538),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF16445A)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('scan-history-search'),
                  controller: _searchController,
                  autofillHints: const ['off'],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search scans',
                    prefixIcon: Icon(Icons.search_rounded),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 38,
                      minHeight: 40,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 132,
                child: DropdownButtonFormField<String>(
                  key: const Key('scan-history-type-filter'),
                  initialValue: _scanTypeFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Type',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All types')),
                    DropdownMenuItem(value: 'message', child: Text('Messages')),
                    DropdownMenuItem(value: 'url', child: Text('URLs')),
                    DropdownMenuItem(
                      value: 'screenshot',
                      child: Text('Screenshots'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _scanTypeFilter = value);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.error != null)
          _ErrorCard(
            message: 'Could not load scan history: ${widget.error}',
            onRetry: widget.onRefresh,
          ),
        if (widget.isLoading && widget.entries.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (entries.isEmpty &&
            widget.entries.isEmpty &&
            widget.error == null)
          const _EmptyStateCard(
            icon: Icons.history_rounded,
            title: 'No scan history yet',
            message: 'Your saved scans will appear here.',
          )
        else if (entries.isEmpty && widget.entries.isNotEmpty)
          const _EmptyStateCard(
            icon: Icons.search_off_rounded,
            title: 'No matching scans',
            message: 'Try a different search or scan-type filter.',
          )
        else
          for (final entry in entries)
            _ScanHistoryCard(
              entry: entry,
              onTap: () => widget.onOpenEntry(entry),
            ),
        if (widget.hasMore)
          OutlinedButton(
            key: const Key('load-more-scan-history'),
            onPressed: widget.isLoading ? null : widget.onLoadMore,
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Load older scans'),
          )
        else if (widget.entries.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'End of scan history',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9BB2C9), fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  const _ScanHistoryCard({required this.entry, required this.onTap});

  final ScanHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (entry.riskLevel) {
      ScanRiskLevel.low => const Color(0xFF34F5AA),
      ScanRiskLevel.medium => const Color(0xFFFFC46B),
      ScanRiskLevel.high => const Color(0xFFFF7777),
      ScanRiskLevel.critical => const Color(0xFFFF4444),
      ScanRiskLevel.unknown => const Color(0xFF9BB2C9),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        key: Key('scan-history-${entry.id}'),
        color: const Color(0xFF082538),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF16445A)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('open-scan-history-${entry.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 94,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 11),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    entry.scanType == 'url'
                        ? Icons.link_rounded
                        : entry.scanType == 'screenshot'
                        ? Icons.image_outlined
                        : Icons.chat_bubble_outline_rounded,
                    color: riskColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_scanTypeLabel(entry.scanType)} scan',
                              style: const TextStyle(
                                color: Color(0xFFEAF4FF),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF8DA7BB),
                            size: 17,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _classificationLabel(entry.classification),
                              style: TextStyle(
                                color: riskColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ),
                          Text(
                            '${_riskLabelForResult(entry.riskLevel)} risk · '
                            '${entry.confidence}% confidence',
                            style: const TextStyle(
                              color: Color(0xFF9BB2C9),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.analysisSummary ??
                            (entry.indicators.isEmpty
                                ? 'No known indicators were recorded; this is not a safety verdict.'
                                : 'Warning signs found: ${entry.indicators.join(', ')}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFBDD0E1),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF8DA7BB),
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatDateTime(entry.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF8DA7BB),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _scanTypeLabel(String scanType) => switch (scanType) {
  'message' => 'Message',
  'url' => 'URL',
  'screenshot' => 'Screenshot',
  _ => throw StateError('Unsupported scan type: $scanType'),
};

String _riskLabel(ScanRiskLevel riskLevel) => switch (riskLevel) {
  ScanRiskLevel.low => 'LOW',
  ScanRiskLevel.medium => 'MEDIUM',
  ScanRiskLevel.high => 'HIGH',
  ScanRiskLevel.critical => 'CRITICAL',
  ScanRiskLevel.unknown => 'UNDETERMINED',
};

class _FamilyDashboard extends StatelessWidget {
  const _FamilyDashboard({
    required this.family,
    required this.isLoading,
    required this.error,
    required this.alertFeed,
    required this.onRefresh,
    required this.onMarkAlertRead,
    required this.onOpenAlert,
    required this.onPermissionCenter,
    required this.onCreate,
    required this.onInvite,
    required this.onRevokeInvite,
    required this.onAcceptInvite,
    required this.onRemoveMember,
    required this.onSharingChanged,
    required this.onDeleteFamily,
    required this.onLeaveFamily,
  });

  final FamilyGroup? family;
  final bool isLoading;
  final Object? error;
  final ValueListenable<_AlertFeed> alertFeed;
  final Future<void> Function() onRefresh;
  final Future<void> Function(SecurityAlert) onMarkAlertRead;
  final Future<void> Function(SecurityAlert) onOpenAlert;
  final Future<void> Function() onPermissionCenter;
  final VoidCallback onCreate;
  final VoidCallback onInvite;
  final ValueChanged<String> onRevokeInvite;
  final VoidCallback onAcceptInvite;
  final ValueChanged<FamilyMember> onRemoveMember;
  final ValueChanged<bool> onSharingChanged;
  final VoidCallback onDeleteFamily;
  final VoidCallback onLeaveFamily;

  @override
  Widget build(BuildContext context) {
    return _DashboardScroll(
      children: [
        const _PageIntro(
          title: 'Family Protection',
          subtitle: 'Keep your family safer, together.',
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          _ErrorCard(
            message: 'Could not load family data: $error',
            onRetry: onRefresh,
          )
        else if (family == null)
          _EmptyFamilyState(
            onCreate: onCreate,
            onAcceptInvite: onAcceptInvite,
            onPermissionCenter: onPermissionCenter,
          )
        else
          _FamilyGroupContent(
            family: family!,
            alertFeed: alertFeed,
            onMarkAlertRead: onMarkAlertRead,
            onOpenAlert: onOpenAlert,
            onPermissionCenter: onPermissionCenter,
            onInvite: onInvite,
            onRevokeInvite: onRevokeInvite,
            onRemoveMember: onRemoveMember,
            onSharingChanged: onSharingChanged,
            onDeleteFamily: onDeleteFamily,
            onLeaveFamily: onLeaveFamily,
          ),
      ],
    );
  }
}

class _EmptyFamilyState extends StatelessWidget {
  const _EmptyFamilyState({
    required this.onCreate,
    required this.onAcceptInvite,
    required this.onPermissionCenter,
  });

  final VoidCallback onCreate;
  final VoidCallback onAcceptInvite;
  final Future<void> Function() onPermissionCenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EmptyStateCard(
          icon: Icons.groups_2_outlined,
          title: 'No family group yet',
          message: 'Create a family group or join with an invitation code.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('create-family'),
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create family group'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('accept-family-invite'),
          onPressed: onAcceptInvite,
          icon: const Icon(Icons.key_rounded),
          label: const Text('Join with invitation code'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('family-permission-control'),
          onPressed: onPermissionCenter,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Permission control'),
        ),
      ],
    );
  }
}

class _FamilyGroupContent extends StatelessWidget {
  const _FamilyGroupContent({
    required this.family,
    required this.alertFeed,
    required this.onMarkAlertRead,
    required this.onOpenAlert,
    required this.onPermissionCenter,
    required this.onInvite,
    required this.onRevokeInvite,
    required this.onRemoveMember,
    required this.onSharingChanged,
    required this.onDeleteFamily,
    required this.onLeaveFamily,
  });

  final FamilyGroup family;
  final ValueListenable<_AlertFeed> alertFeed;
  final Future<void> Function(SecurityAlert) onMarkAlertRead;
  final Future<void> Function(SecurityAlert) onOpenAlert;
  final Future<void> Function() onPermissionCenter;
  final VoidCallback onInvite;
  final ValueChanged<String> onRevokeInvite;
  final ValueChanged<FamilyMember> onRemoveMember;
  final ValueChanged<bool> onSharingChanged;
  final VoidCallback onDeleteFamily;
  final VoidCallback onLeaveFamily;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B6755), Color(0xFF07384A)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF128A6B)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.home_work_rounded,
                color: Color(0xFF8CFFD0),
                size: 35,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFEAF4FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _FamilyStatusPill(
                          icon: Icons.groups_2_rounded,
                          label:
                              '${family.members.length} ${family.members.length == 1 ? 'member' : 'members'}',
                        ),
                        _FamilyStatusPill(
                          icon: family.shareReports
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          label: family.shareReports ? 'Sharing on' : 'Private',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (family.isOwner)
                IconButton(
                  key: const Key('invite-family'),
                  tooltip: 'Invite family member',
                  onPressed: onInvite,
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF9FFFD5),
                  ),
                ),
              IconButton(
                key: const Key('family-permission-control'),
                tooltip: 'Permission control',
                onPressed: onPermissionCenter,
                icon: const Icon(Icons.tune_rounded, color: Color(0xFFB7F9DD)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionHeading(title: 'Family Members'),
        const SizedBox(height: 8),
        _SectionCard(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    for (final member in family.members)
                      SizedBox(
                        width: 64,
                        child: _FamilyMemberAvatar(
                          member: member,
                          onRemove: family.isOwner && !member.isOwner
                              ? () => onRemoveMember(member)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              if (family.isOwner && family.pendingInvites.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pending invitations',
                    style: TextStyle(
                      color: Color(0xFFEAF4FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                for (final invitation in family.pendingInvites)
                  ListTile(
                    key: Key('pending-invite-${invitation.email}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF3A321F),
                      child: Icon(Icons.mail_outline, color: Color(0xFFFFC46B)),
                    ),
                    title: Text(invitation.email),
                    subtitle: Text(
                      'Invitation expires ${_formatDate(invitation.expiresAt)}',
                    ),
                    trailing: IconButton(
                      key: Key('revoke-invite-${invitation.email}'),
                      tooltip: 'Cancel invitation',
                      onPressed: () => onRevokeInvite(invitation.email),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ),
              ],
              if (family.isOwner) ...[
                const Divider(),
                SwitchListTile(
                  key: const Key('family-sharing-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow shared scam reports'),
                  subtitle: Text(
                    family.shareReports
                        ? 'Reports are shared only when the author opts in.'
                        : 'Previously shared reports are hidden while sharing is off.',
                  ),
                  value: family.shareReports,
                  onChanged: onSharingChanged,
                ),
              ],
              if (family.members.length == 1 && family.isOwner)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Invite a member to start sharing reports.',
                    style: TextStyle(color: Color(0xFF9BB2C9), fontSize: 12),
                  ),
                ),
              if (family.isOwner)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('delete-family'),
                    onPressed: onDeleteFamily,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete family group'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB63A3A),
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('leave-family'),
                    onPressed: onLeaveFamily,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Leave family group'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder<_AlertFeed>(
          valueListenable: alertFeed,
          builder: (context, feed, child) {
            final familyAlerts = feed.alerts
                .where((alert) => alert.familyId == family.id)
                .toList(growable: false);
            return _FamilyActivitySection(
              alerts: familyAlerts,
              onMarkAlertRead: onMarkAlertRead,
              onOpenAlert: onOpenAlert,
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: _SectionHeading(title: 'Family Threat Reports'),
            ),
            if (family.shareReports)
              const _FamilyStatusPill(
                icon: Icons.lock_open_rounded,
                label: 'Shared by choice',
              ),
          ],
        ),
        const SizedBox(height: 8),
        _FamilyReportSummary(reports: family.reports),
        const SizedBox(height: 10),
        if (!family.shareReports)
          const _EmptyStateCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Report sharing is off',
            message: 'Turn sharing on to view or share family reports.',
          )
        else if (family.reports.isEmpty)
          const _EmptyStateCard(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'No shared reports yet',
            message:
                'Reports appear here only when an author chooses to share.',
          )
        else
          for (final report in family.reports)
            _SectionCard(
              key: ValueKey(
                '${report.createdAt.toIso8601String()}-${report.category}',
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.report_outlined,
                  color: Color(0xFFDC6B35),
                ),
                title: Text(report.category),
                subtitle: Text(report.description),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Shared report',
                      style: TextStyle(
                        color: Color(0xFF8FD5C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(report.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF9FB5C2),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _FamilyReportSummary extends StatelessWidget {
  const _FamilyReportSummary({required this.reports});

  final List<SharedReport> reports;

  @override
  Widget build(BuildContext context) {
    final categories = reports.map((report) => report.category).toSet().length;
    final latest = reports.isEmpty
        ? null
        : _formatDate(reports.first.createdAt);
    return Row(
      children: [
        Expanded(
          child: _FamilyReportMetric(
            label: 'Shared reports',
            value: '${reports.length}',
            icon: Icons.description_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FamilyReportMetric(
            label: 'Categories',
            value: '$categories',
            icon: Icons.category_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FamilyReportMetric(
            label: 'Latest',
            value: latest ?? 'None',
            icon: Icons.schedule_outlined,
          ),
        ),
      ],
    );
  }
}

class _FamilyReportMetric extends StatelessWidget {
  const _FamilyReportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF102B3D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E4B5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF73EFC3), size: 17),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEAF4FF),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8DA7BB), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FamilyActivitySection extends StatelessWidget {
  const _FamilyActivitySection({
    required this.alerts,
    required this.onMarkAlertRead,
    required this.onOpenAlert,
  });

  final List<SecurityAlert> alerts;
  final Future<void> Function(SecurityAlert) onMarkAlertRead;
  final Future<void> Function(SecurityAlert) onOpenAlert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeading(title: 'Family activity')),
            if (alerts.any((alert) => !alert.isRead))
              _FamilyStatusPill(
                icon: Icons.fiber_new_rounded,
                label: '${alerts.where((alert) => !alert.isRead).length} new',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          const _EmptyStateCard(
            icon: Icons.notifications_none_rounded,
            title: 'No family activity yet',
            message:
                'Shared reports and family security events will appear here.',
          )
        else
          for (final alert in alerts.take(10))
            _SectionCard(
              key: Key('family-alert-${alert.id}'),
              child: InkWell(
                onTap: () => onOpenAlert(alert),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      alert.severity == 'high'
                          ? Icons.warning_amber_rounded
                          : Icons.notifications_active_outlined,
                      color: alert.severity == 'high'
                          ? const Color(0xFFFFB36B)
                          : const Color(0xFF73EFC3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEAF4FF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.detail,
                            style: const TextStyle(
                              color: Color(0xFF9BB2C9),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDateTime(alert.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF718CA5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!alert.isRead)
                      IconButton(
                        key: Key('mark-family-alert-read-${alert.id}'),
                        tooltip: 'Mark as read',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onMarkAlertRead(alert),
                        icon: const Icon(Icons.done_rounded, size: 19),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF34F5AA)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyStatusPill extends StatelessWidget {
  const _FamilyStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x2634F5AA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4034F5AA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFB7F9DD)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB7F9DD),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberAvatar extends StatelessWidget {
  const _FamilyMemberAvatar({required this.member, this.onRemove});

  final FamilyMember member;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _ProfileAvatar(
              key: Key('family-member-${member.userId}'),
              firstName: member.displayName,
              lastName: '',
              email: member.displayName,
              imageUrl: member.avatarUrl,
              size: 46,
            ),
            if (onRemove != null)
              Positioned(
                right: -9,
                top: -9,
                child: IconButton(
                  key: Key('remove-family-member-${member.userId}'),
                  tooltip: 'Remove ${member.displayName}',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 25,
                    height: 25,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF12384A),
                    foregroundColor: const Color(0xFFB7CFDF),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFEAF4FF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          member.isOwner ? 'Owner' : 'Member',
          style: const TextStyle(color: Color(0xFF9BB2C9), fontSize: 9),
        ),
      ],
    );
  }
}

class _AlertsPage extends StatelessWidget {
  const _AlertsPage({
    required this.alertFeed,
    required this.onMarkRead,
    required this.onOpenAlert,
    required this.onRetry,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.scanHistory,
    required this.scanHistoryLoading,
    required this.scanHistoryHasMore,
    required this.scanHistoryError,
    required this.onRefreshScanHistory,
    required this.onLoadMoreScanHistory,
    required this.onOpenEntry,
  });

  final ValueListenable<_AlertFeed> alertFeed;
  final ValueChanged<SecurityAlert> onMarkRead;
  final Future<void> Function(SecurityAlert) onOpenAlert;
  final VoidCallback onRetry;
  final ValueListenable<int> selectedSection;
  final ValueChanged<int> onSectionSelected;
  final List<ScanHistoryEntry> scanHistory;
  final bool scanHistoryLoading;
  final bool scanHistoryHasMore;
  final Object? scanHistoryError;
  final Future<void> Function() onRefreshScanHistory;
  final Future<void> Function() onLoadMoreScanHistory;
  final ValueChanged<ScanHistoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return _DashboardScroll(
      children: [
        const _PageIntro(
          title: 'History',
          subtitle: 'Your saved scan results and alerts in one place.',
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<int>(
          valueListenable: selectedSection,
          builder: (context, feed, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<int>(
                  key: const Key('history-section-selector'),
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.history_rounded),
                      label: Text('Scans'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.notifications_none_rounded),
                      label: Text('Alerts'),
                    ),
                  ],
                  selected: {feed},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      onSectionSelected(selection.first),
                ),
                const SizedBox(height: 16),
                Offstage(
                  offstage: feed != 0,
                  child: _ScanHistoryPanel(
                    entries: scanHistory,
                    isLoading: scanHistoryLoading,
                    hasMore: scanHistoryHasMore,
                    error: scanHistoryError,
                    onRefresh: onRefreshScanHistory,
                    onLoadMore: onLoadMoreScanHistory,
                    onOpenEntry: onOpenEntry,
                  ),
                ),
                Offstage(
                  offstage: feed != 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionHeading(title: 'Recent alerts'),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<_AlertFeed>(
                        valueListenable: alertFeed,
                        builder: (context, alerts, _) {
                          final Widget content;
                          if (alerts.error != null) {
                            content = KeyedSubtree(
                              key: const ValueKey('alerts-error'),
                              child: _ErrorCard(
                                message:
                                    'Could not load alerts: ${alerts.error}',
                                onRetry: () async => onRetry(),
                              ),
                            );
                          } else if (alerts.isLoading) {
                            content = const KeyedSubtree(
                              key: ValueKey('alerts-loading'),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (alerts.alerts.isEmpty) {
                            content = const KeyedSubtree(
                              key: ValueKey('alerts-empty'),
                              child: _EmptyStateCard(
                                icon: Icons.notifications_none_rounded,
                                title: 'You’re all caught up',
                                message:
                                    'There are no alerts available to show.',
                              ),
                            );
                          } else {
                            content = KeyedSubtree(
                              key: ValueKey(
                                alerts.alerts
                                    .map((alert) => alert.id)
                                    .join('|'),
                              ),
                              child: Column(
                                children: [
                                  for (final alert in alerts.alerts)
                                    _AlertCard(
                                      alert: alert,
                                      onMarkRead: onMarkRead,
                                      onOpenAlert: onOpenAlert,
                                    ),
                                ],
                              ),
                            );
                          }
                          return _DashboardAnimatedSwitcher(child: content);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, this.onMarkRead, this.onOpenAlert});

  final SecurityAlert alert;
  final ValueChanged<SecurityAlert>? onMarkRead;
  final Future<void> Function(SecurityAlert)? onOpenAlert;

  @override
  Widget build(BuildContext context) {
    final color = alert.severity == 'high'
        ? const Color(0xFFB63A3A)
        : alert.severity == 'review'
        ? const Color(0xFFFFC46B)
        : const Color(0xFF27C6F5);
    return InkWell(
      onTap: onOpenAlert == null ? null : () => onOpenAlert!(alert),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: Key('security-alert-${alert.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF082538),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert.isRead
                ? const Color(0xFF16445A)
                : color.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                alert.severity == 'high'
                    ? Icons.warning_amber_rounded
                    : Icons.notifications_active_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(
                            color: Color(0xFFEAF4FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.detail,
                    style: const TextStyle(
                      color: Color(0xFFBDD0E1),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatDate(alert.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF8DA7BB),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (!alert.isRead && onMarkRead != null)
              IconButton(
                key: Key('mark-alert-read-${alert.id}'),
                tooltip: 'Mark as read',
                visualDensity: VisualDensity.compact,
                onPressed: () => onMarkRead!(alert),
                icon: const Icon(Icons.done_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.avatarError,
    required this.onRefreshAvatar,
    required this.onSignOut,
    required this.onUpdateProfile,
    required this.onUploadProfilePhoto,
    required this.privacySettings,
    required this.privacySettingsLoading,
    required this.privacySettingsError,
    required this.privacySettingsSaving,
    required this.onRefreshPrivacySettings,
    required this.onPrivacySettingsChanged,
    required this.onOpenTrustedIntelligence,
    required this.onOpenAccountSecurity,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? avatarError;
  final Future<void> Function() onRefreshAvatar;
  final VoidCallback onSignOut;
  final Future<void> Function({
    required String firstName,
    required String lastName,
    required String email,
  })
  onUpdateProfile;
  final Future<String> Function({
    required Uint8List bytes,
    required String contentType,
  })
  onUploadProfilePhoto;
  final PrivacySettings? privacySettings;
  final bool privacySettingsLoading;
  final Object? privacySettingsError;
  final bool privacySettingsSaving;
  final Future<void> Function() onRefreshPrivacySettings;
  final Future<void> Function(PrivacySettings) onPrivacySettingsChanged;
  final VoidCallback onOpenTrustedIntelligence;
  final VoidCallback onOpenAccountSecurity;

  @override
  Widget build(BuildContext context) {
    return _DashboardScroll(
      children: [
        const _PageIntro(
          title: 'Profile & settings',
          subtitle: 'Keep your account and protection preferences up to date.',
        ),
        const SizedBox(height: 16),
        _ProfileAccountCard(
          email: email,
          firstName: firstName,
          lastName: lastName,
          avatarUrl: avatarUrl,
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => _EditProfileDialog(
              firstName: firstName,
              lastName: lastName,
              email: email,
              avatarUrl: avatarUrl,
              onUploadProfilePhoto: onUploadProfilePhoto,
              onSave: onUpdateProfile,
            ),
          ),
        ),
        if (avatarError != null)
          _ErrorCard(
            message: 'Could not load profile photo: $avatarError',
            onRetry: onRefreshAvatar,
          ),
        const SizedBox(height: 22),
        const _SectionHeading(title: 'Privacy & sharing'),
        const SizedBox(height: 4),
        const Text(
          'Control what Cyvora shares and how family activity is handled.',
          style: TextStyle(color: Color(0xFF9BB2C9), fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (privacySettingsLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (privacySettingsError != null)
          _ErrorCard(
            message:
                'Could not load privacy preferences: '
                '$privacySettingsError',
            onRetry: onRefreshPrivacySettings,
          )
        else if (privacySettings case final settings?)
          _SectionCard(
            key: const Key('privacy-preferences'),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SHARING CONTROLS',
                    style: TextStyle(
                      color: Color(0xFF7FA5B7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _profileSettingSwitch(
                  key: const Key('share-protection-status-setting'),
                  icon: Icons.verified_user_outlined,
                  title: const Text('Share protection status'),
                  subtitle: const Text(
                    'Preference only; status sharing is not active.',
                  ),
                  value: settings.shareProtectionStatus,
                  onChanged: privacySettingsSaving
                      ? null
                      : (value) => onPrivacySettingsChanged(
                          settings.copyWith(shareProtectionStatus: value),
                        ),
                ),
                const Divider(height: 1),
                _profileSettingSwitch(
                  key: const Key('share-scan-results-setting'),
                  icon: Icons.analytics_outlined,
                  title: const Text('Share scan results'),
                  subtitle: const Text(
                    'Preference only; private scan history is not shared.',
                  ),
                  value: settings.shareScanResults,
                  onChanged: privacySettingsSaving
                      ? null
                      : (value) => onPrivacySettingsChanged(
                          settings.copyWith(shareScanResults: value),
                        ),
                ),
                const Divider(height: 1),
                _profileSettingSwitch(
                  key: const Key('share-security-alerts-setting'),
                  icon: Icons.warning_amber_rounded,
                  title: const Text('Share security alerts'),
                  subtitle: const Text(
                    'Preference only; family alert delivery is not active.',
                  ),
                  value: settings.shareSecurityAlerts,
                  onChanged: privacySettingsSaving
                      ? null
                      : (value) => onPrivacySettingsChanged(
                          settings.copyWith(shareSecurityAlerts: value),
                        ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NOTIFICATIONS',
                    style: TextStyle(
                      color: Color(0xFF7FA5B7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _profileSettingSwitch(
                  key: const Key('family-activity-notifications-setting'),
                  icon: Icons.family_restroom_outlined,
                  title: const Text('Family activity notifications'),
                  subtitle: const Text(
                    'Preference only; push notifications are not configured.',
                  ),
                  value: settings.familyActivityNotifications,
                  onChanged: privacySettingsSaving
                      ? null
                      : (value) => onPrivacySettingsChanged(
                          settings.copyWith(familyActivityNotifications: value),
                        ),
                ),
                const Divider(height: 1),
                _profileSettingSwitch(
                  key: const Key('push-notifications-setting'),
                  icon: Icons.notifications_none_rounded,
                  title: const Text('Push notifications'),
                  subtitle: const Text(
                    'Saved preference; push delivery is not implemented.',
                  ),
                  value: settings.pushNotificationsEnabled,
                  onChanged: privacySettingsSaving
                      ? null
                      : (value) => onPrivacySettingsChanged(
                          settings.copyWith(pushNotificationsEnabled: value),
                        ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const _InfoBanner(
          icon: Icons.lock_outline_rounded,
          message:
              'Your choices are saved to your account. Cyvora never shares '
              'scan content or family activity without an enabled preference.',
        ),
        const SizedBox(height: 12),
        const _InfoBanner(
          icon: Icons.shield_outlined,
          message:
              'Real-time device protection is not active. Optional Android '
              'message notification scanning only collects message previews '
              'for your review; calls, browsing, and emergencies are not monitored.',
        ),
        const SizedBox(height: 12),
        const _SectionHeading(title: 'Account & security'),
        const SizedBox(height: 10),
        _ToolCard(
          key: const Key('account-security'),
          icon: Icons.shield_outlined,
          title: 'Account security',
          subtitle: 'Manage SMS two-factor authentication and sign-in.',
          onTap: onOpenAccountSecurity,
        ),
        const SizedBox(height: 18),
        const _SectionHeading(title: 'Community scam intelligence'),
        const SizedBox(height: 8),
        _ToolCard(
          key: const Key('trusted-scam-intelligence'),
          icon: Icons.fact_check_outlined,
          title: 'Review scam examples',
          subtitle: 'Submit examples, track review status, and access moderator tools.',
          onTap: onOpenTrustedIntelligence,
        ),
        const SizedBox(height: 8),
        const _SectionHeading(title: 'Your data'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1B29),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5C3546)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFFF9A9A),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign out',
                      style: TextStyle(
                        color: Color(0xFFFFD8D8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'End your current Cyvora session.',
                      style: TextStyle(color: Color(0xFFBD9DA8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('dashboard-logout'),
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF9A9A),
                ),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

SwitchListTile _profileSettingSwitch({
  required Key key,
  required IconData icon,
  required Widget title,
  required Widget subtitle,
  required bool value,
  required ValueChanged<bool>? onChanged,
}) {
  return SwitchListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    dense: true,
    secondary: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0x1434F5AA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2634F5AA)),
      ),
      child: Icon(icon, color: const Color(0xFF73EFC3), size: 19),
    ),
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: onChanged,
  );
}

class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.onTap,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedFirst = firstName.trim();
    final trimmedLast = lastName.trim();
    final fullName = [
      trimmedFirst,
      trimmedLast,
    ].where((part) => part.isNotEmpty).join(' ');
    return Semantics(
      button: true,
      label: 'Edit profile information',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: const Key('profile-account-card'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0C3C42),
                  Color(0xFF09283D),
                  Color(0xFF082538),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF1A655F)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1820D994),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ProfileAvatar(
                          key: const Key('profile-account-avatar'),
                          firstName: trimmedFirst,
                          lastName: trimmedLast,
                          email: email,
                          imageUrl: avatarUrl,
                          size: 64,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 21,
                            height: 21,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C3C42),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF64F2CC),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF64F2CC),
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCOUNT PROFILE',
                            style: TextStyle(
                              color: Color(0xFF8FBAB7),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            fullName.isEmpty ? 'Your account' : fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFEAF4FF),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            key: const Key('dashboard-email'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB7CFD7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x2634F5AA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0x4034F5AA),
                              ),
                            ),
                            child: const Text(
                              'PROTECTED ACCOUNT',
                              style: TextStyle(
                                color: Color(0xFF9FFFD5),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('edit-profile'),
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit account details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9FFFD5),
                      side: const BorderSide(color: Color(0xFF267A72)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                Container(height: 1, color: const Color(0xFF1C4E58)),
                const SizedBox(height: 13),
                const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF64F2CC),
                      size: 17,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap to edit your name, email, and profile photo.',
                        style: TextStyle(
                          color: Color(0xFFB7CFD7),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _profileInitials(String firstName, String lastName, String email) {
  final names = [
    firstName,
    lastName,
  ].where((name) => name.trim().isNotEmpty).toList(growable: false);
  if (names.length > 1) {
    return names
        .take(2)
        .map((name) => String.fromCharCodes(name.trim().runes.take(1)))
        .join()
        .toUpperCase();
  }
  final source = names.isNotEmpty ? names.first : email.split('@').first;
  return String.fromCharCodes(source.runes.take(2)).toUpperCase();
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.size,
    this.imageUrl,
    this.imageBytes,
  });

  final String firstName;
  final String lastName;
  final String email;
  final double size;
  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageBytes != null || imageUrl != null;
    final initials = _profileInitials(firstName, lastName, email);
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF75F5C1),
          fontSize: size * 0.33,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final Widget image;
    if (imageBytes case final bytes?) {
      image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (imageUrl case final url?) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      image = fallback;
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasPhoto
            ? const Color(0xFF09283D)
            : const Color(0xFF34E89B).withValues(alpha: 0.13),
        border: hasPhoto
            ? null
            : Border.all(
                color: const Color(0xFF34E89B).withValues(alpha: 0.45),
              ),
      ),
      child: image,
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.avatarUrl,
    required this.onUploadProfilePhoto,
    required this.onSave,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String? avatarUrl;
  final Future<String> Function({
    required Uint8List bytes,
    required String contentType,
  })
  onUploadProfilePhoto;
  final Future<void> Function({
    required String firstName,
    required String lastName,
    required String email,
  })
  onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(
    text: widget.firstName,
  );
  late final _lastNameController = TextEditingController(text: widget.lastName);
  late final _emailController = TextEditingController(text: widget.email);
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  Uint8List? _profilePhotoBytes;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving || _isUploadingPhoto) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not update your profile: $error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _chooseProfilePhoto() async {
    if (_isSaving || _isUploadingPhoto) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final contentType =
          image.mimeType ??
          switch (image.name.split('.').last.toLowerCase()) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => null,
          };
      if (contentType == null ||
          !const {
            'image/jpeg',
            'image/png',
            'image/webp',
          }.contains(contentType)) {
        setState(() => _error = 'Choose a JPEG, PNG, or WebP photo.');
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        setState(() => _error = 'Choose a photo smaller than 5 MB.');
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
        _error = null;
      });
      await widget.onUploadProfilePhoto(bytes: bytes, contentType: contentType);
      if (mounted) setState(() => _profilePhotoBytes = bytes);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not update your profile photo: $error');
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not update your profile photo: ${error.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileAvatar(
                  firstName: _firstNameController.text.trim(),
                  lastName: _lastNameController.text.trim(),
                  email: _emailController.text.trim(),
                  imageUrl: widget.avatarUrl,
                  imageBytes: _profilePhotoBytes,
                  size: 76,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('profile-change-photo'),
                  onPressed: _isSaving || _isUploadingPhoto
                      ? null
                      : _chooseProfilePhoto,
                  icon: _isUploadingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _isUploadingPhoto
                        ? 'Uploading photo...'
                        : 'Change profile photo',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('profile-first-name'),
                  controller: _firstNameController,
                  enabled: !_isSaving,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your first name.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('profile-last-name'),
                  controller: _lastNameController,
                  enabled: !_isSaving,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your last name.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('profile-email'),
                  controller: _emailController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) =>
                      value == null || !_emailPattern.hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Changing your email may require confirming the new address. Your current email stays active until confirmation.',
                    style: TextStyle(
                      color: Color(0xFF9BB2C9),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFFF9999),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving || _isUploadingPhoto
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('profile-save'),
          onPressed: _isSaving || _isUploadingPhoto ? null : _save,
          child: _isSaving || _isUploadingPhoto
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }
}

class _ReportDraft {
  const _ReportDraft({
    required this.category,
    required this.description,
    required this.indicator,
    required this.shareWithFamily,
  });

  final String category;
  final String description;
  final String? indicator;
  final bool shareWithFamily;
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.keyboardType,
  });

  final String title;
  final String label;
  final String hint;
  final int maxLength;
  final TextInputType keyboardType;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('dashboard-input'),
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        minLines: 2,
        maxLines: 6,
        keyboardType: widget.keyboardType,
        autofillHints: widget.keyboardType == TextInputType.url
            ? const [AutofillHints.url]
            : const ['off'],
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('dashboard-submit-input'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.canShareWithFamily});

  final bool canShareWithFamily;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const _categories = [
    'Phishing',
    'Impersonation',
    'Payment scam',
    'Fake offer',
    'Other',
  ];

  final _descriptionController = TextEditingController();
  final _indicatorController = TextEditingController();
  String _category = _categories.first;
  bool _shareWithFamily = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report a scam'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('report-category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in _categories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('report-indicator'),
              controller: _indicatorController,
              autofillHints: const [AutofillHints.url],
              maxLength: 2048,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Scam URL or domain (optional)',
                hintText: 'https://example.com',
                helperText: 'Only its normalized hash is stored for review; the URL itself is not saved.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('report-description'),
              controller: _descriptionController,
              autofillHints: const ['off'],
              maxLength: 3000,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'Do not include passwords or verification codes.',
              ),
            ),
            if (widget.canShareWithFamily)
              CheckboxListTile(
                key: const Key('share-report-with-family'),
                contentPadding: EdgeInsets.zero,
                value: _shareWithFamily,
                onChanged: (value) =>
                    setState(() => _shareWithFamily = value ?? false),
                title: const Text('Share this report with my family'),
                controlAffinity: ListTileControlAffinity.leading,
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
          key: const Key('submit-scam-report'),
          onPressed: () {
            final description = _descriptionController.text.trim();
            if (description.isEmpty) {
              setState(() => _error = 'Describe the scam before submitting.');
              return;
            }
            Navigator.pop(
              context,
              _ReportDraft(
                category: _category,
                description: description,
                indicator: _indicatorController.text.trim().isEmpty
                    ? null
                    : _indicatorController.text.trim(),
                shareWithFamily: _shareWithFamily,
              ),
            );
          },
          child: const Text('Save report'),
        ),
      ],
    );
  }
}

class _DashboardScroll extends StatelessWidget {
  const _DashboardScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEAF4FF),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9BB2C9), fontSize: 13),
        ),
      ],
    );
  }
}

class _ProtectionStatusCard extends StatelessWidget {
  const _ProtectionStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3D42), Color(0xFF08283A), Color(0xFF09283D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF176B63), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F20D994),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0B6A57),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFF36F5AA), width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0x2234F5AA), blurRadius: 12),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFFB7FFE0),
              size: 32,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your safety center',
                  style: TextStyle(
                    color: Color(0xFFEAF4FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'On-demand checks are ready when you are. '
                  'Background device protection is not active.',
                  style: TextStyle(
                    color: Color(0xFFC5D9E7),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 8),
                _OnDemandBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(14),
      decoration: _dashboardCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD3E1EC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AnimatedStatisticValue(
            value: value,
            style: const TextStyle(
              color: Color(0xFFEAF4FF),
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatisticCard extends StatelessWidget {
  const _CompactStatisticCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF09283D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD3E1EC),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          _AnimatedStatisticValue(
            value: value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFEAF4FF),
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _OnDemandBadge extends StatelessWidget {
  const _OnDemandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF34F5AA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: Color(0xFF34F5AA), size: 15),
          SizedBox(width: 4),
          Text(
            'ON-DEMAND',
            style: TextStyle(
              color: Color(0xFF65F8BB),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickToolTile extends StatelessWidget {
  const _QuickToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF09283D),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1A4D60)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2D40), Color(0xFF082538)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF34E89B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFF34E89B).withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(icon, color: const Color(0xFF39EBA5), size: 21),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE0EDF5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFF09283D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF16445A)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D3B3D),
          child: Icon(icon, color: const Color(0xFF39EBA5), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9BB2C9), fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF9BB2C9),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _dashboardCardDecoration,
      child: Material(
        color: const Color(0xFF09283D),
        child: DefaultTextStyle(
          style: const TextStyle(color: Color(0xFFEAF4FF)),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: _dashboardCardDecoration,
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9BB2C9), size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9BB2C9),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2A3D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16445A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFBDD0E1), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFBDD0E1),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Color(0xFFB63A3A))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(local)} $hour:$minute $period';
}

const _dashboardCardDecoration = BoxDecoration(
  color: Color(0xFF09283D),
  borderRadius: BorderRadius.all(Radius.circular(16)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFF16445A))),
);
