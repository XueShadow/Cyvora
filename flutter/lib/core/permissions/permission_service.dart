import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionState {
  const NotificationPermissionState({
    required this.isGranted,
    required this.isPermanentlyDenied,
  });

  final bool isGranted;
  final bool isPermanentlyDenied;
}

class PermissionService {
  const PermissionService();

  bool get supportsAndroidNotifications =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<NotificationPermissionState?> notificationStatus() async {
    if (!supportsAndroidNotifications) return null;
    final status = await Permission.notification.status;
    return NotificationPermissionState(
      isGranted: status.isGranted,
      isPermanentlyDenied: status.isPermanentlyDenied,
    );
  }

  Future<NotificationPermissionState?> requestNotifications() async {
    if (!supportsAndroidNotifications) return null;
    final status = await Permission.notification.request();
    return NotificationPermissionState(
      isGranted: status.isGranted,
      isPermanentlyDenied: status.isPermanentlyDenied,
    );
  }

  Future<bool> openSettings() => openAppSettings();
}
