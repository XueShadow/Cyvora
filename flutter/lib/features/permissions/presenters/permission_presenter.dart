import '../models/permission_repository.dart';
import '../models/permission_status.dart';

class PermissionPresenter {
  const PermissionPresenter(this._repository);

  final PermissionRepository _repository;

  Future<PermissionCenterSettings> loadSettings() async {
    if (!_repository.supportsAndroidNotificationMonitoring) {
      return PermissionCenterSettings.unsupported;
    }

    final accessEnabled = await _repository.isNotificationAccessEnabled();
    var consentEnabled = await _repository.isMonitoringConsentEnabled();
    final selectedPackages = await _repository.selectedNotificationApps();
    if (selectedPackages
        .difference(SupportedNotificationApp.supportedPackageNames)
        .isNotEmpty) {
      throw StateError('Stored notification app selection is invalid.');
    }
    if ((!accessEnabled || selectedPackages.isEmpty) && consentEnabled) {
      await _repository.setMonitoringConsent(false);
      consentEnabled = false;
    }

    return PermissionCenterSettings(
      isAndroidSupported: true,
      notificationAccessEnabled: accessEnabled,
      monitoringConsentEnabled: consentEnabled,
      selectedPackages: selectedPackages,
      retentionDays: await _repository.notificationRetentionDays(),
      pendingNotificationCount: await _repository.pendingNotificationCount(),
    );
  }

  Future<void> setSelectedApps(Set<String> packageNames) async {
    final unsupported = packageNames.difference(
      SupportedNotificationApp.supportedPackageNames,
    );
    if (unsupported.isNotEmpty) {
      throw ArgumentError.value(
        unsupported,
        'packageNames',
        'One or more notification apps are not supported.',
      );
    }
    await _repository.setSelectedNotificationApps(packageNames);
    if (packageNames.isEmpty &&
        await _repository.isMonitoringConsentEnabled()) {
      await _repository.setMonitoringConsent(false);
    }
  }

  Future<void> enableMonitoring() async {
    final selectedPackages = await _repository.selectedNotificationApps();
    if (selectedPackages.isEmpty) {
      throw StateError('Select at least one supported app before enabling.');
    }
    await _repository.setMonitoringConsent(true);
  }

  Future<void> disableMonitoring() => _repository.setMonitoringConsent(false);

  Future<void> openNotificationAccessSettings() =>
      _repository.openNotificationAccessSettings();

  Future<void> setRetentionDays(int days) async {
    if (!const {1, 7, 30}.contains(days)) {
      throw ArgumentError.value(days, 'days', 'Unsupported retention period.');
    }
    await _repository.setNotificationRetentionDays(days);
  }

  Future<void> clearPendingNotifications() =>
      _repository.clearPendingNotifications();
}
