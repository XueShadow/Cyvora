import 'package:flutter/foundation.dart';

import '../../core/permissions/message_notification_service.dart';
import '../../features/permissions/models/permission_repository.dart';

class AndroidPermissionRepository implements PermissionRepository {
  const AndroidPermissionRepository([
    this._notificationService = const MessageNotificationService(),
  ]);

  final MessageNotificationService _notificationService;

  @override
  bool get supportsAndroidNotificationMonitoring =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isNotificationAccessEnabled() async {
    if (!supportsAndroidNotificationMonitoring) return false;
    return _notificationService.isEnabled();
  }

  @override
  Future<void> openNotificationAccessSettings() async {
    if (!supportsAndroidNotificationMonitoring) {
      throw UnsupportedError(
        'Android notification access settings are not available on this platform.',
      );
    }
    await _notificationService.openSettings();
  }

  @override
  Future<bool> isMonitoringConsentEnabled() async {
    if (!supportsAndroidNotificationMonitoring) return false;
    return _notificationService.hasMonitoringConsent();
  }

  @override
  Future<void> setMonitoringConsent(bool enabled) async {
    if (!supportsAndroidNotificationMonitoring) {
      throw UnsupportedError(
        'Notification monitoring is only available on Android.',
      );
    }
    await _notificationService.setMonitoringConsent(enabled);
  }

  @override
  Future<Set<String>> selectedNotificationApps() async {
    if (!supportsAndroidNotificationMonitoring) return const {};
    return _notificationService.selectedApps();
  }

  @override
  Future<void> setSelectedNotificationApps(Set<String> packageNames) async {
    if (!supportsAndroidNotificationMonitoring) {
      throw UnsupportedError(
        'Notification monitoring is only available on Android.',
      );
    }
    await _notificationService.setSelectedApps(packageNames);
  }

  @override
  Future<int> notificationRetentionDays() async {
    if (!supportsAndroidNotificationMonitoring) return 7;
    return _notificationService.retentionDays();
  }

  @override
  Future<void> setNotificationRetentionDays(int days) async {
    if (!supportsAndroidNotificationMonitoring) {
      throw UnsupportedError(
        'Notification monitoring is only available on Android.',
      );
    }
    await _notificationService.setRetentionDays(days);
  }

  @override
  Future<int> pendingNotificationCount() async {
    if (!supportsAndroidNotificationMonitoring) return 0;
    return (await _notificationService.pending()).length;
  }

  @override
  Future<void> clearPendingNotifications() async {
    if (!supportsAndroidNotificationMonitoring) {
      throw UnsupportedError(
        'Notification monitoring is only available on Android.',
      );
    }
    await _notificationService.clearPending();
  }
}
