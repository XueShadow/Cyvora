import 'package:cyvora_mobile/features/permissions/models/permission_repository.dart';
import 'package:cyvora_mobile/features/permissions/models/permission_status.dart';
import 'package:cyvora_mobile/features/permissions/presenters/permission_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported platforms use accurate not-required states', () async {
    final presenter = PermissionPresenter(_FakePermissionRepository());

    final settings = await presenter.loadSettings();

    expect(settings.isAndroidSupported, isFalse);
    expect(settings.monitoringStatus, PermissionStatus.notRequired);
  });

  test('monitoring rejects unsupported app packages', () async {
    final presenter = PermissionPresenter(
      _FakePermissionRepository(supportedPlatform: true),
    );

    await expectLater(
      presenter.setSelectedApps({'com.example.unrelated'}),
      throwsArgumentError,
    );
  });

  test('enabling monitoring requires a selected supported app', () async {
    final presenter = PermissionPresenter(
      _FakePermissionRepository(supportedPlatform: true),
    );

    await expectLater(presenter.enableMonitoring(), throwsStateError);
  });
}

class _FakePermissionRepository implements PermissionRepository {
  _FakePermissionRepository({this.supportedPlatform = false});

  final bool supportedPlatform;
  Set<String> selected = {};
  bool consent = false;

  @override
  bool get supportsAndroidNotificationMonitoring => supportedPlatform;

  @override
  Future<bool> isNotificationAccessEnabled() async => supportedPlatform;

  @override
  Future<void> openNotificationAccessSettings() async {}

  @override
  Future<bool> isMonitoringConsentEnabled() async => consent;

  @override
  Future<void> setMonitoringConsent(bool enabled) async {
    consent = enabled;
  }

  @override
  Future<Set<String>> selectedNotificationApps() async => selected;

  @override
  Future<void> setSelectedNotificationApps(Set<String> packageNames) async {
    selected = packageNames;
  }

  @override
  Future<int> notificationRetentionDays() async => 7;

  @override
  Future<void> setNotificationRetentionDays(int days) async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<void> clearPendingNotifications() async {}
}
