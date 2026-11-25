import 'package:flutter/services.dart';

class PendingMessageNotification {
  const PendingMessageNotification({
    required this.id,
    required this.title,
    required this.text,
    required this.packageName,
    required this.receivedAt,
  });

  factory PendingMessageNotification.fromMap(Map<Object?, Object?> map) {
    return PendingMessageNotification(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['receivedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String id;
  final String title;
  final String text;
  final String packageName;
  final DateTime receivedAt;
}

class MessageNotificationService {
  const MessageNotificationService();

  static const _channel = MethodChannel('cyvora/notification_scanning');

  Future<bool> isEnabled() async {
    final enabled = await _channel.invokeMethod<bool>(
      'isNotificationListenerEnabled',
    );
    if (enabled == null) {
      throw StateError(
        'Notification access status was not returned by Android.',
      );
    }
    return enabled;
  }

  Future<void> openSettings() {
    return _channel.invokeMethod<void>('openNotificationListenerSettings');
  }

  Future<List<PendingMessageNotification>> pending() async {
    final values = await _channel.invokeMethod<List<Object?>>(
      'getPendingMessageNotifications',
    );
    if (values == null) {
      throw StateError('Pending notifications were not returned by Android.');
    }
    return values
        .whereType<Map<Object?, Object?>>()
        .map(PendingMessageNotification.fromMap)
        .toList(growable: false);
  }

  Future<void> remove(String id) {
    return _channel.invokeMethod<void>(
      'removePendingMessageNotification',
      <String, Object?>{'id': id},
    );
  }

  Future<void> markCompleted(String id) {
    return _channel.invokeMethod<void>(
      'markPendingMessageNotificationCompleted',
      <String, Object?>{'id': id},
    );
  }

  Future<void> clearPending() {
    return _channel.invokeMethod<void>('clearPendingMessageNotifications');
  }

  Future<Set<String>> selectedApps() async {
    final values = await _channel.invokeMethod<List<Object?>>(
      'getSelectedNotificationApps',
    );
    if (values == null) {
      throw StateError(
        'Selected notification apps were not returned by Android.',
      );
    }
    final packages = <String>{};
    for (final value in values) {
      if (value is! String) {
        throw StateError('Android returned an invalid selected-app entry.');
      }
      packages.add(value);
    }
    return packages;
  }

  Future<void> setSelectedApps(Set<String> packageNames) {
    return _channel.invokeMethod<void>(
      'setSelectedNotificationApps',
      <String, Object?>{'packages': packageNames.toList()..sort()},
    );
  }

  Future<int> retentionDays() async {
    final value = await _channel.invokeMethod<int>(
      'getNotificationRetentionDays',
    );
    if (value == null) {
      throw StateError('Notification retention was not returned by Android.');
    }
    return value;
  }

  Future<void> setRetentionDays(int days) {
    return _channel.invokeMethod<void>(
      'setNotificationRetentionDays',
      <String, Object?>{'days': days},
    );
  }

  Future<bool> hasMonitoringConsent() async {
    final value = await _channel.invokeMethod<bool>(
      'getMessageMonitoringConsent',
    );
    if (value == null) {
      throw StateError(
        'Message monitoring consent was not returned by Android.',
      );
    }
    return value;
  }

  Future<void> setMonitoringConsent(bool granted) {
    return _channel.invokeMethod<void>(
      'setMessageMonitoringConsent',
      <String, Object?>{'granted': granted},
    );
  }
}

enum NotificationScanOutcome { completed, failed, alreadyProcessing, noContent }

class PendingMessageNotificationQueue {
  static const _maxRememberedCompletedIds = 50;

  PendingMessageNotificationQueue({
    required this.remove,
    required this.markCompleted,
  });

  final Future<void> Function(String id) remove;
  final Future<void> Function(String id) markCompleted;
  final Set<String> _processingIds = {};
  final Set<String> _completedIds = {};

  Future<NotificationScanOutcome> scan(
    PendingMessageNotification notification,
    Future<bool> Function(String content, String idempotencyKey) analyze,
  ) async {
    final content = notification.text.isEmpty
        ? notification.title
        : notification.text;
    if (notification.id.isEmpty || content.trim().isEmpty) {
      return NotificationScanOutcome.noContent;
    }
    if (!_processingIds.add(notification.id)) {
      return NotificationScanOutcome.alreadyProcessing;
    }

    try {
      if (_completedIds.contains(notification.id)) {
        await markCompleted(notification.id);
        await remove(notification.id);
        return NotificationScanOutcome.completed;
      }

      if (!await analyze(content, notification.id)) {
        return NotificationScanOutcome.failed;
      }

      _rememberCompleted(notification.id);
      await markCompleted(notification.id);
      await remove(notification.id);
      return NotificationScanOutcome.completed;
    } finally {
      _processingIds.remove(notification.id);
    }
  }

  void _rememberCompleted(String id) {
    _completedIds
      ..remove(id)
      ..add(id);
    if (_completedIds.length > _maxRememberedCompletedIds) {
      _completedIds.remove(_completedIds.first);
    }
  }
}
