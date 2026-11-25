abstract interface class PermissionRepository {
  bool get supportsAndroidNotificationMonitoring;

  Future<bool> isNotificationAccessEnabled();

  Future<void> openNotificationAccessSettings();

  Future<bool> isMonitoringConsentEnabled();

  Future<void> setMonitoringConsent(bool enabled);

  Future<Set<String>> selectedNotificationApps();

  Future<void> setSelectedNotificationApps(Set<String> packageNames);

  Future<int> notificationRetentionDays();

  Future<void> setNotificationRetentionDays(int days);

  Future<int> pendingNotificationCount();

  Future<void> clearPendingNotifications();
}
