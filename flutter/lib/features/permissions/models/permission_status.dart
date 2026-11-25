enum PermissionStatus { enabled, disabled, notGranted, restricted, notRequired }

extension PermissionStatusLabel on PermissionStatus {
  String get label => switch (this) {
    PermissionStatus.enabled => 'Enabled',
    PermissionStatus.disabled => 'Disabled',
    PermissionStatus.notGranted => 'Not granted',
    PermissionStatus.restricted => 'Restricted',
    PermissionStatus.notRequired => 'Not required',
  };
}

class SupportedNotificationApp {
  const SupportedNotificationApp({
    required this.packageName,
    required this.name,
    required this.description,
  });

  final String packageName;
  final String name;
  final String description;

  static const supported = <SupportedNotificationApp>[
    SupportedNotificationApp(
      packageName: 'com.google.android.apps.messaging',
      name: 'Google Messages',
      description: 'SMS and RCS message notifications',
    ),
    SupportedNotificationApp(
      packageName: 'com.samsung.android.messaging',
      name: 'Samsung Messages',
      description: 'SMS and RCS message notifications',
    ),
    SupportedNotificationApp(
      packageName: 'com.whatsapp',
      name: 'WhatsApp',
      description: 'Direct-message notifications',
    ),
    SupportedNotificationApp(
      packageName: 'org.telegram.messenger',
      name: 'Telegram',
      description: 'Direct-message notifications',
    ),
    SupportedNotificationApp(
      packageName: 'com.facebook.orca',
      name: 'Messenger',
      description: 'Direct-message notifications',
    ),
    SupportedNotificationApp(
      packageName: 'org.thoughtcrime.securesms',
      name: 'Signal',
      description: 'Direct-message notifications',
    ),
  ];

  static Set<String> get supportedPackageNames =>
      supported.map((app) => app.packageName).toSet();
}

class PermissionCenterSettings {
  const PermissionCenterSettings({
    required this.isAndroidSupported,
    required this.notificationAccessEnabled,
    required this.monitoringConsentEnabled,
    required this.selectedPackages,
    required this.retentionDays,
    required this.pendingNotificationCount,
  });

  final bool isAndroidSupported;
  final bool notificationAccessEnabled;
  final bool monitoringConsentEnabled;
  final Set<String> selectedPackages;
  final int retentionDays;
  final int pendingNotificationCount;

  bool get monitoringEnabled =>
      isAndroidSupported &&
      notificationAccessEnabled &&
      monitoringConsentEnabled &&
      selectedPackages.isNotEmpty;

  PermissionStatus get notificationAccessStatus => !isAndroidSupported
      ? PermissionStatus.notRequired
      : notificationAccessEnabled
      ? PermissionStatus.enabled
      : PermissionStatus.notGranted;

  PermissionStatus get monitoringStatus => !isAndroidSupported
      ? PermissionStatus.notRequired
      : monitoringEnabled
      ? PermissionStatus.enabled
      : PermissionStatus.disabled;

  static const unsupported = PermissionCenterSettings(
    isAndroidSupported: false,
    notificationAccessEnabled: false,
    monitoringConsentEnabled: false,
    selectedPackages: {},
    retentionDays: 7,
    pendingNotificationCount: 0,
  );
}
