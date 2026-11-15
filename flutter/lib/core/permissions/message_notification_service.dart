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
    return await _channel.invokeMethod<bool>('isNotificationListenerEnabled') ??
        false;
  }

  Future<void> openSettings() {
    return _channel.invokeMethod<void>('openNotificationListenerSettings');
  }

  Future<List<PendingMessageNotification>> pending() async {
    final values = await _channel.invokeMethod<List<Object?>>(
      'getPendingMessageNotifications',
    );
    return (values ?? const <Object?>[])
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
}
