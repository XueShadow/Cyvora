import 'dart:async';

import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cyvora_mobile/auth_gate.dart';
import 'package:cyvora_mobile/auth_screen.dart';
import 'package:cyvora_mobile/main.dart';
import 'package:cyvora_mobile/mfa_challenge_screen.dart';
import 'package:cyvora_mobile/splash_screen.dart';
import 'package:cyvora_mobile/dashboard/dashboard_repository.dart';
import 'package:cyvora_mobile/dashboard/heuristic_scanner.dart';
import 'package:cyvora_mobile/dashboard/trusted_intelligence_page.dart';

void main() {
  test('dashboard summary counts review-level scans as warning signs', () {
    final summary = DashboardSummary.fromRiskLevels([
      'low',
      'review',
      'high',
      'unknown',
    ]);

    expect(summary.scansToday, 4);
    expect(summary.warningScansToday, 2);
    expect(summary.lowRiskScansToday, 1);
  });

  testWidgets('trusted example feedback requires a user label choice', (
    WidgetTester tester,
  ) async {
    String? submittedLabel;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                submittedLabel = await showDialog<String>(
                  context: context,
                  builder: (context) => const TrustedExampleFeedbackDialog(
                    contentType: 'message',
                  ),
                );
              },
              child: const Text('Open report'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not change this scan'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-trusted-example')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(RadioListTile<String>).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-trusted-example')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('submit-trusted-example')));
    await tester.pumpAndSettle();
    expect(submittedLabel, 'scam');
  });

  testWidgets('splash screen animates and transitions smoothly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(destination: Scaffold(body: Text('Destination'))),
      ),
    );

    expect(find.text('Scan. Check. Stay Safe.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();

    expect(find.text('Destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash screen handles a temporarily tiny viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2, 2);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(destination: Scaffold(body: Text('Destination'))),
      ),
    );

    expect(find.text('Scan. Check. Stay Safe.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Cyvora login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));

    expect(find.byKey(const Key('brand-title')), findsOneWidget);
    expect(find.text('Scan. Check. Stay Safe.'), findsOneWidget);
    expect(find.byKey(const Key('first-name-field')), findsNothing);
    expect(find.byKey(const Key('last-name-field')), findsNothing);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('dashboard shows the signed-in user and supports sign out', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: () async {
            signedOut = true;
          },
          repository: _FakeDashboardRepository(),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboard-title')), findsNothing);
    expect(find.text('Hello, person'), findsOneWidget);
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(
      find.textContaining('Background device protection is not active.'),
      findsOneWidget,
    );
    expect(find.text('Today'), findsNothing);
    expect(find.text('Flags found'), findsNothing);
    expect(find.text('Not a safety verdict'), findsNothing);
    expect(find.text('Quick Scan'), findsOneWidget);
    expect(find.text('Quick Tools'), findsOneWidget);
    expect(find.text('ON-DEMAND'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-greeting-profile')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-notifications')), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byKey(const Key('ai-assistant')))
          .tooltip,
      'Safety Assistant',
    );
    expect(find.byTooltip('Safety Assistant'), findsOneWidget);
    expect(find.text('Safety Assistant'), findsNothing);
    expect(find.byTooltip('Profile and settings'), findsNothing);

    await tester.tap(find.byKey(const Key('ai-assistant')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assistant-page')), findsOneWidget);
    expect(find.byKey(const Key('safety-assistant-input')), findsOneWidget);
    expect(find.text('Ask about staying safe online'), findsOneWidget);
    expect(
      find.textContaining('Chats are saved only on this device'),
      findsOneWidget,
    );
    expect(find.text('Choose server analysis'), findsNothing);
    await tester.tap(find.byKey(const Key('safety-assistant-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-notifications')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-title'))).data,
      'History',
    );
    expect(find.text('Recent alerts'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-title')), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard-greeting-profile')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-title'))).data,
      'Profile',
    );
    expect(find.byKey(const Key('dashboard-email')), findsOneWidget);
    expect(find.byKey(const Key('profile-account-card')), findsOneWidget);
    expect(find.text('PE'), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('dashboard-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-logout')));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });

  testWidgets('Safety Assistant automatically replies in a chat thread', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeDashboardRepository()
      ..assistantReply =
          'If you sent money or shared a code:\n\n1. **Contact your bank**\n2. Change the affected account password using the official app.';
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ai-assistant')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('safety-assistant-input')),
      'A message asks me to send my login code.',
    );
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('safety-assistant-send')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('safety-assistant-send')));
    await tester.pumpAndSettle();

    expect(repository.assistantChatRequests, 1);
    expect(repository.serverAnalysisRequests, 0);
    expect(
      find.text('A message asks me to send my login code.'),
      findsOneWidget,
    );
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Contact your bank'), findsOneWidget);
    expect(
      find.text('Change the affected account password using the official app.'),
      findsOneWidget,
    );
    expect(
      repository.lastAssistantConversation
          .map((message) => message.toJson())
          .toList(),
      [
        {'role': 'user', 'content': 'A message asks me to send my login code.'},
      ],
    );
    expect(find.text('Choose server analysis'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('safety-assistant-input')),
      'What if I already shared it?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety-assistant-send')));
    await tester.pumpAndSettle();
    expect(repository.assistantChatRequests, 2);
    expect(
      repository.lastAssistantConversation
          .map((message) => message.toJson())
          .toList(),
      [
        {'role': 'user', 'content': 'A message asks me to send my login code.'},
        {'role': 'assistant', 'content': repository.assistantReply},
        {'role': 'user', 'content': 'What if I already shared it?'},
      ],
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('safety-assistant-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-assistant')));
    await tester.pumpAndSettle();
    expect(find.text('What if I already shared it?'), findsOneWidget);
    expect(find.text('Contact your bank'), findsNWidgets(2));
    expect(repository.assistantChatRequests, 2);
    expect(repository.serverAnalysisRequests, 0);
    expect(repository.scanHistory, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    final chatKey = preferences.getKeys().singleWhere(
      (key) => key.startsWith('cyvora.safety_assistant.'),
    );
    final savedConversation = preferences.getString(chatKey);
    expect(
      savedConversation,
      contains('A message asks me to send my login code.'),
    );
    expect(savedConversation, contains('What if I already shared it?'));
  });

  testWidgets('dashboard reports a stalled summary and offers retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: _FakeDashboardRepository(
            summaryLoader: () => Completer<DashboardSummary>().future,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    expect(find.text('Could not load today’s scan summary.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard reports a stalled initial alerts stream', (
    WidgetTester tester,
  ) async {
    final alerts = StreamController<List<SecurityAlert>>();
    addTearDown(alerts.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: _FakeDashboardRepository(alertStream: alerts.stream),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    expect(find.textContaining('Could not load alerts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile card edits account name and email', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          firstName: 'Ada',
          lastName: 'Lovelace',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-account-card')));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.byKey(const Key('profile-change-photo')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('profile-first-name')),
      'Grace',
    );
    await tester.enterText(
      find.byKey(const Key('profile-last-name')),
      'Hopper',
    );
    await tester.enterText(
      find.byKey(const Key('profile-email')),
      'grace@example.com',
    );
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(repository.updatedProfileFirstName, 'Grace');
    expect(repository.updatedProfileLastName, 'Hopper');
    expect(repository.updatedProfileEmail, 'grace@example.com');
    expect(find.text('Grace Hopper'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello, Grace Hopper'), findsOneWidget);
    expect(find.textContaining('Confirm your new email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account security enrolls and verifies an SMS factor', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('account-security')));
    await tester.tap(find.byKey(const Key('account-security')));
    await tester.pumpAndSettle();

    expect(find.text('Two-factor authentication is off'), findsOneWidget);
    await tester.tap(find.byKey(const Key('change-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-password')),
      'StrongPassword123!',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-new-password')),
      'StrongPassword123!',
    );
    await tester.tap(find.byKey(const Key('save-new-password')));
    await tester.pumpAndSettle();
    expect(repository.updatedPassword, 'StrongPassword123!');
    expect(
      find.text('Your password was changed successfully.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('mfa-phone-number')));
    await tester.enterText(
      find.byKey(const Key('mfa-phone-number')),
      '+14155552671',
    );
    await tester.ensureVisible(find.byKey(const Key('start-sms-mfa')));
    await tester.tap(find.byKey(const Key('start-sms-mfa')));
    await tester.pumpAndSettle();

    expect(repository.enrolledPhoneNumber, '+14155552671');
    expect(repository.phoneFactorChallenges, 1);
    expect(find.textContaining('Resend in '), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-sms-code')), '123456');
    await tester.tap(find.text('Verify phone'));
    await tester.pumpAndSettle();

    expect(find.text('Two-factor authentication is on'), findsOneWidget);
    expect(
      find.text('SMS two-factor authentication is enabled.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account security rejects non-E.164 phone numbers', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('account-security')));
    await tester.tap(find.byKey(const Key('account-security')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('mfa-phone-number')),
      '09175551234',
    );
    await tester.tap(find.byKey(const Key('start-sms-mfa')));
    await tester.pumpAndSettle();

    expect(repository.enrolledPhoneNumber, isNull);
    expect(
      find.textContaining('valid phone number in international format'),
      findsOneWidget,
    );
  });

  testWidgets('sign-in MFA challenge verifies a code before continuing', (
    WidgetTester tester,
  ) async {
    var requestedFactorId = '';
    var verifiedCode = '';
    var didVerify = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MfaChallengeScreen(
          factors: const [
            (id: 'phone-factor', label: 'Mobile ending 2671', isPhone: true),
          ],
          onRequestCode: (factorId) async {
            requestedFactorId = factorId;
            return 'challenge-1';
          },
          onVerifyCode: (factorId, challengeId, code) async {
            expect(factorId, 'phone-factor');
            expect(challengeId, 'challenge-1');
            verifiedCode = code;
          },
          onVerified: () => didVerify = true,
          onSignOut: _noopAsync,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedFactorId, 'phone-factor');
    await tester.enterText(find.byKey(const Key('login-mfa-code')), '654321');
    await tester.tap(find.byKey(const Key('verify-login-mfa')));
    await tester.pumpAndSettle();

    expect(verifiedCode, '654321');
    expect(didVerify, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile photo appears on Home and Family Protection', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..family = const FamilyGroup(
        id: 'family-1',
        name: 'My Family',
        ownerId: 'owner-1',
        isOwner: true,
        shareReports: true,
        members: [
          FamilyMember(
            userId: 'owner-1',
            displayName: 'Ada Lovelace',
            isOwner: true,
            avatarUrl: 'https://family.example/avatar',
          ),
        ],
        pendingInvites: [],
        reports: [],
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'ada@example.com',
          firstName: 'Ada',
          lastName: 'Lovelace',
          avatarPath: 'owner-1/avatar',
          userId: 'owner-1',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final homeAvatar = find.byKey(const Key('home-profile-avatar'));
    expect(homeAvatar, findsOneWidget);
    final homeImage = tester.widget<Image>(
      find.descendant(of: homeAvatar, matching: find.byType(Image)),
    );
    expect(
      (tester
                  .widget<Container>(
                    find.descendant(
                      of: homeAvatar,
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .border,
      isNull,
    );
    expect(
      (homeImage.image as NetworkImage).url,
      repository.uploadedProfilePhotoUrl,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('Family'),
      ),
    );
    await tester.pumpAndSettle();

    final familyAvatar = find.byKey(const Key('family-member-owner-1'));
    expect(familyAvatar, findsOneWidget);
    final familyImage = tester.widget<Image>(
      find.descendant(of: familyAvatar, matching: find.byType(Image)),
    );
    expect(
      (tester
                  .widget<Container>(
                    find.descendant(
                      of: familyAvatar,
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .border,
      isNull,
    );
    expect(
      (familyImage.image as NetworkImage).url,
      'https://family.example/avatar',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile privacy preferences load and save independently', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final protectionSharing = find.byKey(
      const Key('share-protection-status-setting'),
    );
    expect(tester.widget<SwitchListTile>(protectionSharing).value, isFalse);

    await tester.ensureVisible(protectionSharing);
    await tester.tap(protectionSharing);
    await tester.pumpAndSettle();

    expect(repository.privacySettings.shareProtectionStatus, isTrue);
    expect(repository.privacySettings.shareScanResults, isFalse);
    expect(find.text('Privacy preferences saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard combines history and alerts in one tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: _FakeDashboardRepository(),
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-title'))).data,
      'History',
    );
    expect(find.byKey(const Key('history-section-selector')), findsOneWidget);
    expect(find.text('Recent alerts'), findsNothing);
    expect(find.text('Saved scans'), findsOneWidget);
    expect(find.text('No scan history yet'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('Alerts'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Recent alerts'), findsOneWidget);
    expect(find.text('There are no alerts available to show.'), findsOneWidget);

    final navigation = find.byKey(const Key('dashboard-navigation'));
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    final viewHistory = find.byKey(const Key('view-scan-history'));
    await tester.ensureVisible(viewHistory);
    await tester.tap(viewHistory);
    await tester.pumpAndSettle();
    expect(find.text('Saved scans'), findsOneWidget);
    expect(find.text('Recent alerts'), findsNothing);

    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    final viewAlerts = find.byKey(const Key('view-all-alerts'));
    await tester.ensureVisible(viewAlerts);
    await tester.tap(viewAlerts);
    await tester.pumpAndSettle();
    expect(find.text('Recent alerts'), findsOneWidget);

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(find.text('Family Protection'), findsOneWidget);
    expect(find.text('No family group yet'), findsOneWidget);
    expect(
      find.text('Create a family group or join with an invitation code.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard navigation respects reduced-motion settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            devicePixelRatio: 1,
            disableAnimations: true,
          ),
          child: DashboardScreen(
            email: 'person@example.com',
            onSignOut: _noopAsync,
            repository: _FakeDashboardRepository(),
          ),
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-title'))).data,
      'History',
    );
    expect(find.text('Saved scans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history presents unread alerts in clean summary cards', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..alerts.add(
        SecurityAlert(
          id: 'unread-alert',
          title: 'Review a scan result',
          detail: 'Warning signs were found in this message.',
          severity: 'review',
          createdAt: DateTime(2026, 11, 12),
          isRead: false,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('security-alert-unread-alert')),
      findsOneWidget,
    );
    expect(find.text('Review a scan result'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-alert-read-unread-alert')));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsNothing);
    expect(find.byKey(const Key('mark-alert-read-unread-alert')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home alert cards open their full details', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..alerts.add(
        SecurityAlert(
          id: 'home-alert',
          title: 'New family scam report',
          detail: 'A family member reported a suspicious message.',
          severity: 'high',
          createdAt: DateTime(2026, 11, 12, 9, 30),
          isRead: false,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final homeAlert = find.text('New family scam report');
    await tester.ensureVisible(homeAlert);
    await tester.tap(homeAlert);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('New family scam report'), findsNWidgets(2));
    expect(
      find.text('A family member reported a suspicious message.'),
      findsNWidgets(2),
    );
    expect(find.text('Severity: HIGH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard keeps tab state while swiping between pages', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: _FakeDashboardRepository(),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('dashboard-tab-pages')),
      const Offset(-280, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard-title'))).data,
      'Family',
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('scan-history-search'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'keep this filter');
    final navigation = find.byKey(const Key('dashboard-navigation'));
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('History')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(search).controller?.text,
      'keep this filter',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'message scan requires consent before sending content to AI providers',
    (WidgetTester tester) async {
      final repository = _FakeDashboardRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            email: 'person@example.com',
            onSignOut: _noopAsync,
            repository: repository,
          ),
        ),
      );

      await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
      await tester.enterText(
        find.byKey(const Key('dashboard-input')),
        'Please review this message.',
      );
      await tester.tap(find.byKey(const Key('dashboard-submit-input')));
      await tester.pumpAndSettle();

      expect(find.text('Choose server analysis'), findsOneWidget);
      expect(find.textContaining('at most one'), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan-with-ai')));
      await tester.pumpAndSettle();

      expect(repository.aiProviderAnalysisRequests, 1);
      expect(repository.serverAnalysisRequests, 1);
      expect(repository.scanHistory, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AI scan result explains evidence and displays prevention tips', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..analysisResult = const ScanResult(
        level: ScanRiskLevel.medium,
        classification: ScanClassification.suspicious,
        confidence: 72,
        indicators: [
          'Urgent or coercive language',
          'Unexpected prize, reward, or refund',
          'Suspicious or unusual URL characteristics',
        ],
        summary: 'Flagged for urgent language, an unexpected prize, and a suspicious URL. These are warning signs, not proof of who sent the message.',
        guidance: 'Verify independently.',
        recommendedActions: [
          'Do not click or reply while the request is unverified.',
          'Never share passwords, one-time codes, PINs, or payment details.',
        ],
        aiAnalysis: {
          'status': 'available',
          'provider': 'groq',
          'summary': 'The message promises a cash prize and urges quick action through an unverified link. That combination can pressure someone to disclose personal or payment details, but the sender and destination have not been independently verified.',
          'signals': [
            'Urgent or coercive language',
            'Unexpected prize, reward, or refund',
          ],
          'recommended_actions': [
            'Do not click the message link or reply to claim the prize.',
            'Verify the offer using the organization’s official app or website.',
            'Never share a password or one-time code to receive a reward.',
          ],
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'You won a prize. Click now.',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-with-ai')));
    await tester.pumpAndSettle();

    expect(find.text('AI-assisted analysis'), findsOneWidget);
    expect(find.text('Why it raised a concern'), findsOneWidget);
    expect(
      find.textContaining('promises a cash prize and urges quick action'),
      findsOneWidget,
    );
    expect(find.text('Signals in this scan'), findsOneWidget);
    expect(find.text('How to prevent similar scams'), findsOneWidget);
    expect(
      find.textContaining(
        'Verify the offer using the organization’s official app or website.',
      ),
      findsOneWidget,
    );
    expect(find.text('Prevention steps'), findsOneWidget);
    final preventionStep = find.text(
      'Do not click or reply while the request is unverified.',
    );
    expect(preventionStep, findsOneWidget);
    expect(
      tester.getTopLeft(preventionStep).dy,
      lessThan(tester.getTopLeft(find.text('Internal analysis modules')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows server analysis errors without mislabeling them as save failures',
    (WidgetTester tester) async {
      final repository = _FakeDashboardRepository()
        ..scanError = const FunctionsHttpException(
          status: 503,
          details: {
            'error': 'AI-provider analysis is temporarily unavailable.',
          },
        );
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            email: 'person@example.com',
            onSignOut: _noopAsync,
            repository: repository,
          ),
        ),
      );

      await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
      await tester.enterText(
        find.byKey(const Key('dashboard-input')),
        'Please review this message.',
      );
      await tester.tap(find.byKey(const Key('dashboard-submit-input')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scan-with-ai')));
      await tester.pumpAndSettle();

      expect(
        find.text('AI-provider analysis is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.textContaining('Could not save this scan'), findsNothing);
      expect(repository.scanHistory, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling the analysis choice does not run or save a scan', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'Please review this message.',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.serverAnalysisRequests, 0);
    expect(repository.scanHistory, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standard scan always uses the centralized server', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'Please review this message.',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-with-scam-intelligence')));
    await tester.pumpAndSettle();

    expect(repository.serverAnalysisRequests, 1);
    expect(repository.scanHistory, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('server scan shows reviewed local indicator evidence', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..analysisResult = const ScanResult(
        level: ScanRiskLevel.critical,
        classification: ScanClassification.scam,
        confidence: 88,
        summary: 'A reviewed local indicator matched exactly.',
        guidance: 'Do not open this link.',
        indicators: ['Malicious or suspicious link destination'],
        evidence: ['A reviewed local indicator matched this exact URL.'],
        analysisModulesStatus: {'local_indicator_database': 'completed'},
        analysisModules: [
          {
            'module': 'local_indicator_database',
            'indicator_type': 'url',
            'status': 'completed',
            'evidence_kind': 'confirmed_detection',
            'confidence': 0.95,
            'evidence': ['A reviewed local indicator matched this exact URL.'],
            'source': 'Cyvora local indicator database',
            'checked_at': '2026-11-13T00:00:00.000Z',
            'indicator_hash': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'category': 'Phishing',
            'details': {'matching_reports': 1},
          },
        ],
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'Check https://example.test/login',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-with-scam-intelligence')));
    await tester.pumpAndSettle();

    expect(find.text('MALICIOUS'), findsAtLeastNWidgets(1));
    expect(find.text('88% classification confidence'), findsOneWidget);
    expect(find.text('Risk assessment: Critical'), findsOneWidget);
    final moduleTile = find.text('Local Indicator Database · URL');
    expect(moduleTile, findsOneWidget);
    await tester.ensureVisible(moduleTile);
    await tester.tap(moduleTile);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('reviewed local indicator'),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('URL scans use the centralized independent analysis engine', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..analysisResult = const ScanResult(
        level: ScanRiskLevel.medium,
        classification: ScanClassification.suspicious,
        confidence: 45,
        indicators: ['Suspicious or unusual URL characteristics'],
        summary: 'The result requires independent verification.',
        guidance: 'Verify independently.',
        aiAnalysis: {
          'status': 'failed',
          'providers_tried': ['gemini', 'groq', 'cloudflare', 'sambanova'],
          'provider_attempts': [
            {
              'provider': 'gemini',
              'status': 'authentication_error',
              'http_status': 401,
            },
            {
              'provider': 'groq',
              'status': 'request_rejected',
              'http_status': 400,
            },
            {
              'provider': 'cloudflare',
              'status': 'model_retired',
              'http_status': 410,
            },
            {
              'provider': 'sambanova',
              'status': 'billing_required',
              'http_status': 402,
            },
            {'provider': 'gemini', 'status': 'circuit_open'},
            {'provider': 'groq', 'status': 'provider_budget_exhausted'},
          ],
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('home-quick-scan-url'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('dashboard-input')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.url),
    );
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'https://example.com/landing',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('local rules and reviewed indicator data'),
      findsAtLeastNWidgets(1),
    );
    final reputationConsent = find.byKey(
      const Key('scan-url-reputation-consent'),
    );
    expect(reputationConsent, findsOneWidget);
    await tester.ensureVisible(reputationConsent);
    await tester.pumpAndSettle();
    await tester.tap(reputationConsent);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('full URL (including its path and query values'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('scan-with-scam-intelligence')));
    await tester.pumpAndSettle();

    expect(repository.serverAnalysisRequests, 1);
    expect(repository.urlReputationRequests, 1);
    expect(repository.scanHistory, hasLength(1));
    expect(
      find.text('Google Gemini: authentication failed (HTTP 401)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Groq: request rejected; check model and request settings (HTTP 400)',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Cloudflare Workers AI: model retired; choose a supported model (HTTP 410)',
      ),
      findsOneWidget,
    );
    expect(
      find.text('SambaNova: billing or a paid plan is required (HTTP 402)'),
      findsOneWidget,
    );
    expect(
      find.text('Google Gemini: temporarily disabled after repeated failures'),
      findsOneWidget,
    );
    expect(
      find.text('Groq: provider daily request limit reached'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan history can be searched and filtered by type', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..scanHistory.addAll([
        ScanHistoryEntry(
          id: 'scan-high',
          scanType: 'message',
          riskLevel: ScanRiskLevel.high,
          indicators: const ['Urgent pressure or account-threat language'],
          createdAt: DateTime(2026, 11, 12),
        ),
        ScanHistoryEntry(
          id: 'scan-url',
          scanType: 'url',
          riskLevel: ScanRiskLevel.medium,
          indicators: const ['The link does not use HTTPS'],
          createdAt: DateTime(2026, 11, 11),
        ),
      ]);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('scan-history-search'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          )
          .autofillHints,
      contains('off'),
    );
    expect(find.byKey(const Key('scan-history-scan-high')), findsOneWidget);
    expect(find.byKey(const Key('scan-history-scan-url')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('scan-history-search')),
      'Urgent pressure',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-history-scan-high')), findsOneWidget);
    expect(find.byKey(const Key('scan-history-scan-url')), findsNothing);

    await tester.tap(find.byKey(const Key('scan-history-search')));
    await tester.enterText(find.byKey(const Key('scan-history-search')), '');
    await tester.pumpAndSettle();
    final typeFilter = find.byKey(const Key('scan-history-type-filter'));
    await tester.ensureVisible(typeFilter);
    await tester.tap(typeFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('URLs').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-history-scan-high')), findsNothing);
    expect(find.byKey(const Key('scan-history-scan-url')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history opens full scan details with the scan time', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..scanHistory.add(
        ScanHistoryEntry(
          id: 'detailed-scan',
          scanType: 'url',
          riskLevel: ScanRiskLevel.high,
          classification: ScanClassification.suspicious,
          confidence: 83,
          indicators: const ['Unexpected redirect'],
          createdAt: DateTime(2026, 11, 12, 14, 5),
          analyzedAt: DateTime(2026, 11, 12, 14, 5),
          analysisSummary: 'The URL uses a recently registered domain.',
          recommendedActions: const ['Open the official app instead.'],
          analysisModulesStatus: const {
            'local_indicator_database': 'completed',
          },
          confidenceReasons: const ['The domain is newly registered.'],
          ruleAnalysis: const {
            'score': 8,
            'categories': ['credential_harvesting'],
            'indicators': ['Brand impersonation'],
            'version': 'rules-3',
          },
          aiAnalysis: const {
            'status': 'available',
            'provider': 'groq',
            'summary': 'It imitates a login page.',
            'signals': ['Brand impersonation'],
            'recommended_actions': ['Do not enter login details.'],
          },
          evidence: const ['The domain is newly registered.'],
          engineVersion: 'bantai-independent-analysis-1',
          analysisModules: const [
            {
              'module': 'local_indicator_database',
              'indicator_type': 'url',
              'status': 'completed',
              'evidence_kind': 'confirmed_detection',
              'confidence': 0.95,
              'evidence': ['A reviewed source matched this URL.'],
              'source': 'Cyvora local indicator database',
              'checked_at': '2026-11-12T14:05:00.000Z',
              'indicator_hash': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'category': 'Phishing',
              'details': {'matching_reports': 1},
            },
          ],
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('11/12/2026 2:05 PM'), findsOneWidget);
    final detailedEntry = find.byKey(
      const Key('open-scan-history-detailed-scan'),
    );
    await tester.ensureVisible(detailedEntry);
    await tester.tap(detailedEntry);
    await tester.pumpAndSettle();

    expect(find.text('URL scan details'), findsOneWidget);
    expect(find.text('Rule-based findings'), findsOneWidget);
    expect(find.text('Rule score: 8'), findsOneWidget);
    expect(find.text('Supporting evidence'), findsOneWidget);
    expect(find.text('AI-assisted analysis'), findsOneWidget);
    expect(find.text('Prevention steps'), findsOneWidget);
    expect(find.text('Internal analysis modules'), findsOneWidget);
    expect(
      find.textContaining('Analysis engine: bantai-independent'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Last analysis: 11/12/2026 2:05 PM'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan history loads older records in pages', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository()
      ..scanHistory.addAll([
        for (var index = 0; index < 51; index++)
          ScanHistoryEntry(
            id: 'scan-$index',
            scanType: 'message',
            riskLevel: ScanRiskLevel.low,
            indicators: const [],
            createdAt: DateTime(
              2026,
              11,
              12,
            ).subtract(Duration(minutes: index)),
          ),
      ]);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-navigation')),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan-history-scan-50')), findsNothing);
    final loadOlder = find.byKey(const Key('load-more-scan-history'));
    await tester.ensureVisible(loadOlder);
    await tester.tap(loadOlder);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan-history-scan-50')), findsOneWidget);
    expect(find.text('End of scan history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard report action saves a scam report', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('report-scam'));

    expect(find.text('Report a scam'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('report-indicator')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.url),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('report-description')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains('off'),
    );
    await tester.enterText(
      find.byKey(const Key('report-description')),
      'A caller asked for a one-time code.',
    );
    await tester.enterText(
      find.byKey(const Key('report-indicator')),
      'https://scam.example/login',
    );
    await tester.tap(find.byKey(const Key('submit-scam-report')));
    await tester.pumpAndSettle();
    expect(
      find.text('Scam report saved. Indicator submitted for review.'),
      findsOneWidget,
    );
    expect(repository.lastReportedIndicator, 'https://scam.example/login');
  });

  testWidgets('family-shared report refreshes Family Protection data', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await repository.createFamily('My Family');
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('report-scam'));
    await tester.tap(find.byKey(const Key('share-report-with-family')));
    await tester.enterText(
      find.byKey(const Key('report-description')),
      'A caller asked for a one-time code.',
    );
    await tester.tap(find.byKey(const Key('submit-scam-report')));
    await tester.pumpAndSettle();

    expect(repository.familyLoadRequests, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('family tab creates and loads a family group', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-family')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'My Family',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();

    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('Allow shared scam reports'), findsOneWidget);
    expect(repository.family?.name, 'My Family');
    expect(tester.takeException(), isNull);
  });

  testWidgets('family header wraps status pills on compact phones', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await repository.createFamily('My Family');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    expect(find.text('My Family'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family activity shows shared alerts with read action', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await repository.createFamily('My Family');
    repository.alerts.add(
      SecurityAlert(
        id: 'family-alert-1',
        familyId: 'family-1',
        title: 'New family scam report',
        detail: 'A family member shared a scam report.',
        severity: 'review',
        createdAt: DateTime(2026, 11, 15),
        isRead: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    expect(find.text('Family activity'), findsOneWidget);
    expect(find.text('New family scam report'), findsOneWidget);
    expect(
      find.byKey(const Key('mark-family-alert-read-family-alert-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'family invitation creates a shareable code without email setup',
    (WidgetTester tester) async {
      final repository = _FakeDashboardRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            email: 'person@example.com',
            onSignOut: _noopAsync,
            repository: repository,
          ),
        ),
      );

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-family')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dashboard-input')),
        'My Family',
      );
      await tester.tap(find.byKey(const Key('dashboard-submit-input')));
      await tester.pumpAndSettle();

      repository.inviteCode = const FamilyInviteCode(
        invitationCode:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      await tester.tap(find.byKey(const Key('invite-family')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dashboard-input')),
        'invitee@example.com',
      );
      await tester.tap(find.byKey(const Key('dashboard-submit-input')));
      await tester.pumpAndSettle();

      expect(find.text('Share this invitation code'), findsOneWidget);
      expect(find.textContaining('invitee@example.com'), findsOneWidget);
      expect(find.byKey(const Key('family-invitation-code')), findsOneWidget);
      expect(find.textContaining('expires in 7 days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('family invitation shows a copyable manual code', (
    WidgetTester tester,
  ) async {
    final repository = _FakeDashboardRepository();
    await repository.createFamily('My Family');
    repository.inviteCode = const FamilyInviteCode(
      invitationCode:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    final inviteFamily = find.byKey(const Key('invite-family'));
    await tester.ensureVisible(inviteFamily);
    await tester.tap(inviteFamily);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'invitee@example.com',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('sign in to Cyvora using that email address'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('family-invitation-code')), findsOneWidget);
    expect(
      find.byKey(const Key('copy-family-invitation-code')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual invitation code remains available if family refresh fails',
    (WidgetTester tester) async {
      final repository = _FakeDashboardRepository();
      await repository.createFamily('My Family');
      repository.inviteCode = const FamilyInviteCode(
        invitationCode:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            email: 'person@example.com',
            onSignOut: _noopAsync,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.failNextFamilyLoad = true;

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      final inviteFamily = find.byKey(const Key('invite-family'));
      await tester.ensureVisible(inviteFamily);
      await tester.tap(inviteFamily);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dashboard-input')),
        'invitee@example.com',
      );
      await tester.tap(find.byKey(const Key('dashboard-submit-input')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('family-invitation-code')), findsOneWidget);
      expect(
        find.textContaining('Family data did not refresh'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scan form displays the server assessment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: _FakeDashboardRepository(),
        ),
      ),
    );

    await _openHomeQuickTool(tester, const Key('home-quick-scan-message'));
    await tester.enterText(
      find.byKey(const Key('dashboard-input')),
      'Urgent: verify your password now and pay by gift card. Keep it secret.',
    );
    await tester.tap(find.byKey(const Key('dashboard-submit-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-with-scam-intelligence')));
    await tester.pumpAndSettle();

    expect(find.text('UNKNOWN'), findsOneWidget);
    expect(find.text('Risk assessment: Undetermined'), findsOneWidget);
    expect(
      find.textContaining('Analysis completed on the test server.'),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard navigation fits a compact phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          onSignOut: _noopAsync,
          repository: _FakeDashboardRepository(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final scanCard = find.byKey(const Key('dashboard-stat-scans'));
    final warningCard = find.byKey(const Key('dashboard-stat-warnings'));
    final noPatternCard = find.byKey(const Key('dashboard-stat-no-pattern'));
    expect(scanCard, findsOneWidget);
    expect(warningCard, findsOneWidget);
    expect(noPatternCard, findsOneWidget);
    expect(find.text('Scans'), findsOneWidget);
    expect(find.text('Warning signs'), findsOneWidget);
    expect(find.text('No pattern'), findsOneWidget);
    expect(
      find.descendant(of: scanCard, matching: find.text('Today')),
      findsNothing,
    );
    expect(
      find.descendant(of: warningCard, matching: find.text('Flags found')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: noPatternCard,
        matching: find.text('Not a safety verdict'),
      ),
      findsNothing,
    );
    expect(
      tester.widget<Text>(find.text('Warning signs')).textAlign,
      TextAlign.center,
    );
    expect({
      tester.getTopLeft(scanCard).dy,
      tester.getTopLeft(warningCard).dy,
      tester.getTopLeft(noPatternCard).dy,
    }, hasLength(1));
    final messageTool = find.descendant(
      of: find.byKey(const Key('home-quick-scan-message')),
      matching: find.byType(Material),
    );
    expect(tester.getSize(messageTool).width, greaterThan(120));
    expect(tester.getSize(messageTool).height, greaterThanOrEqualTo(104));
    expect(tester.widget<Text>(find.text('Scan\nMessage')).style?.fontSize, 12);

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(find.text('Family Protection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches to account creation form', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));

    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-name-field')), findsOneWidget);
    expect(find.byKey(const Key('last-name-field')), findsOneWidget);
    expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.byKey(const Key('policy-consent-checkbox')), findsOneWidget);
    expect(find.byKey(const Key('terms-policy-link')), findsOneWidget);
    expect(find.byKey(const Key('privacy-policy-link')), findsOneWidget);
    expect(find.text('Not strong yet'), findsOneWidget);
  });

  testWidgets('password indicator follows the signup password requirements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('password-field')),
      'abcdefghijkl',
    );
    await tester.pump();
    expect(find.text('Not strong yet'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('password-field')),
      'Abcdefghijk1',
    );
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
  });

  testWidgets('opens Terms and Privacy policy pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('terms-policy-link')));
    await tester.tap(find.byKey(const Key('terms-policy-link')));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsNWidgets(2));
    expect(find.textContaining('Draft'), findsNothing);
    expect(find.textContaining('not an emergency'), findsOneWidget);
    expect(find.textContaining('Ji Monsales'), findsOneWidget);
    expect(
      find.textContaining('For support or questions about these terms'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('privacy-policy-link')));
    await tester.tap(find.byKey(const Key('privacy-policy-link')));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsNWidgets(2));
    expect(find.textContaining('Information collected'), findsOneWidget);
    expect(find.textContaining('Republic Act No. 10173'), findsOneWidget);
    expect(find.textContaining('data portability'), findsOneWidget);
  });

  testWidgets('password visibility toggle reveals and masks password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    final editableTextFinder = find.descendant(
      of: find.byKey(const Key('password-field')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editableTextFinder).obscureText, isTrue);

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(editableTextFinder).obscureText,
      isFalse,
    );

    await tester.ensureVisible(find.byTooltip('Hide password'));
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editableTextFinder).obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    final confirmPasswordField = tester.widget<TextFormField>(
      find.byKey(const Key('confirm-password-field')),
    );
    expect(confirmPasswordField.controller, isNotNull);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('confirm-password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
  });

  testWidgets('shows an enabled Remember Me option on login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.ensureVisible(find.byKey(const Key('remember-me')));

    expect(find.text('Remember me'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('validates required login fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
  });

  testWidgets('accepts a valid email and password on the login form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'secure123',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsNothing);
    expect(find.text('Use at least 6 characters'), findsNothing);
    expect(
      find.text(
        'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to sign in.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('rejects malformed email addresses during account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'StrongPass123!',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'StrongPass123!',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('requires first and last name during account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'StrongPass123!',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'StrongPass123!',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name'), findsOneWidget);
    expect(find.text('Enter your last name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepts a valid email address for account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('first-name-field')), 'Taylor');
    await tester.enterText(find.byKey(const Key('last-name-field')), 'Example');
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'StrongPass123!',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'StrongPass123!',
    );
    await tester.ensureVisible(
      find.byKey(const Key('policy-consent-checkbox')),
    );
    await tester.tap(find.byKey(const Key('policy-consent-checkbox')));
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(
      find.text(
        'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to sign in.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('rejects a signup password that misses the strength rule', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('first-name-field')), 'Taylor');
    await tester.enterText(find.byKey(const Key('last-name-field')), 'Example');
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'Abcdefghijk',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'Abcdefghijk',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(
      find.text('Use at least 12 characters and 3 of 4 character types'),
      findsOneWidget,
    );
    expect(find.text('Not strong yet'), findsOneWidget);
  });

  testWidgets('requires policy consent before account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('first-name-field')), 'Taylor');
    await tester.enterText(find.byKey(const Key('last-name-field')), 'Example');
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'StrongPass123!',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'StrongPass123!',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Agree to the Terms and acknowledge the Privacy Policy to continue',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Use at least 12 characters and 3 of 4 character types'),
      findsNothing,
    );
  });

  testWidgets('auth forms expose browser-appropriate autofill hints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('first-name-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.givenName),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('last-name-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.familyName),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('email-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.email),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.newPassword),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('confirm-password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.newPassword),
    );

    await tester.tap(find.byKey(const Key('tab-Log In')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('email-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.username),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .autofillHints,
      contains(AutofillHints.password),
    );
  });

  testWidgets(
    'email confirmation screen displays the address and return action',
    (WidgetTester tester) async {
      var returnedToLogin = false;
      var resendRequested = false;
      await tester.pumpWidget(
        MaterialApp(
          home: EmailConfirmationScreen(
            email: 'person@example.com',
            onBackToLogin: () => returnedToLogin = true,
            onResendConfirmation: () async => resendRequested = true,
          ),
        ),
      );

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text('person@example.com'), findsOneWidget);
      expect(find.textContaining('follow its link'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('resend-confirmation')));
      await tester.tap(find.byKey(const Key('resend-confirmation')));
      await tester.pumpAndSettle();
      expect(resendRequested, isTrue);
      await tester.ensureVisible(find.byKey(const Key('back-to-login')));
      await tester.tap(find.byKey(const Key('back-to-login')));
      expect(returnedToLogin, isTrue);
    },
  );

  testWidgets('PKCE callback recovery offers sign-in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthCallbackRecoveryScreen()),
    );

    expect(find.text('Continue to Cyvora'), findsOneWidget);
    expect(find.textContaining('same browser'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-to-sign-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('email confirmation screen fits a compact phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EmailConfirmationScreen(
          email: 'person@example.com',
          onBackToLogin: _noop,
          onResendConfirmation: _noopAsync,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('email-confirmation-screen')), findsOneWidget);
    expect(find.byKey(const Key('back-to-login')), findsOneWidget);
  });

  testWidgets('fits a compact phone viewport without layout overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('submit-auth')), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);

    await tester.tap(find.byKey(const Key('tab-Create Account')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
  });

  testWidgets('uses a responsive split layout on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Modern protection for your account, messages, and family.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('email-field')), findsOneWidget);
  });

  test('server result model preserves unified classifications', () {
    const result = ScanResult(
      level: ScanRiskLevel.critical,
      classification: ScanClassification.scam,
      confidence: 99,
      indicators: ['Known malicious link'],
      summary: 'Threat intelligence confirmed a known threat.',
      guidance: 'Do not open the link.',
      recommendedActions: ['Do not open the link.'],
      analysisModulesStatus: {'local_indicator_database': 'completed'},
      evidence: ['A reviewed local indicator matched exactly.'],
      engineVersion: 'bantai-independent-analysis-1',
    );

    expect(result.classification, ScanClassification.scam);
    expect(result.level, ScanRiskLevel.critical);
    expect(result.confidence, 99);
    expect(
      result.analysisModulesStatus['local_indicator_database'],
      'completed',
    );
  });
}

void _noop() {}

Future<void> _noopAsync() async {}

Future<void> _openHomeQuickTool(WidgetTester tester, Key key) async {
  final tool = find.byKey(key);
  await tester.ensureVisible(tool);
  await tester.tap(tool);
  await tester.pumpAndSettle();
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.summaryLoader, this.alertStream});

  final Future<DashboardSummary> Function()? summaryLoader;
  final Stream<List<SecurityAlert>>? alertStream;
  FamilyGroup? family;
  FamilyInviteCode? inviteCode;
  String? lastReportedIndicator;
  PrivacySettings privacySettings = const PrivacySettings();
  List<AccountSecurityFactor> accountSecurityFactors = [];
  int phoneFactorChallenges = 0;
  String? enrolledPhoneNumber;
  int passwordResetRequests = 0;
  String? updatedPassword;
  String? updatedProfileFirstName;
  String? updatedProfileLastName;
  String? updatedProfileEmail;
  String? requestedAvatarPath;
  String uploadedProfilePhotoUrl = 'https://example.invalid/avatar';
  int profilePhotoUploads = 0;
  final List<ScanHistoryEntry> scanHistory = [];
  bool failNextFamilyLoad = false;
  int familyLoadRequests = 0;
  Exception? scanError;
  int serverAnalysisRequests = 0;
  int aiProviderAnalysisRequests = 0;
  int urlReputationRequests = 0;
  int assistantChatRequests = 0;
  String assistantReply = 'Here is a helpful safety answer.';
  List<AssistantChatMessage> lastAssistantConversation = const [];
  final List<TrustedExampleStatus> trustedExampleStatuses = [];
  final List<TrustedReviewSubmission> trustedReviewQueue = [];
  final List<TrustedDatasetVersion> trustedDatasetVersions = [];
  ScanResult analysisResult = const ScanResult(
    level: ScanRiskLevel.unknown,
    classification: ScanClassification.unknown,
    confidence: 20,
    indicators: [],
    summary: 'Analysis completed on the test server.',
    guidance: 'Evidence is insufficient to classify this content.',
  );
  final List<SecurityAlert> alerts = [];

  @override
  Future<DashboardSummary> loadSummary() =>
      summaryLoader?.call() ??
      Future.value(
        const DashboardSummary(
          scansToday: 0,
          warningScansToday: 0,
          lowRiskScansToday: 0,
        ),
      );

  @override
  Future<List<ScanHistoryEntry>> loadScanHistory({
    required int offset,
    required int limit,
  }) async {
    if (offset >= scanHistory.length) return const [];
    final end = (offset + limit).clamp(0, scanHistory.length).toInt();
    return scanHistory.sublist(offset, end);
  }

  @override
  Future<PrivacySettings> loadPrivacySettings() async => privacySettings;

  @override
  Future<void> updatePrivacySettings(PrivacySettings settings) async {
    privacySettings = settings;
  }

  @override
  Future<void> requestPasswordReset() async {
    passwordResetRequests++;
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
  }

  @override
  Future<List<AccountSecurityFactor>> loadAccountSecurityFactors() async =>
      accountSecurityFactors;

  @override
  Future<String> enrollPhoneFactor(String phoneNumber) async {
    enrolledPhoneNumber = phoneNumber;
    accountSecurityFactors = [
      ...accountSecurityFactors,
      const AccountSecurityFactor(
        id: 'phone-factor-1',
        type: 'phone',
        status: 'unverified',
        friendlyName: 'Mobile ending 2671',
      ),
    ];
    return 'phone-factor-1';
  }

  @override
  Future<PhoneFactorChallenge> sendPhoneFactorChallenge(String factorId) async {
    phoneFactorChallenges++;
    return PhoneFactorChallenge(
      id: 'challenge-$phoneFactorChallenges',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> verifyPhoneFactorChallenge({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    accountSecurityFactors = accountSecurityFactors
        .map(
          (factor) => factor.id == factorId
              ? AccountSecurityFactor(
                  id: factor.id,
                  type: factor.type,
                  status: 'verified',
                  friendlyName: factor.friendlyName,
                )
              : factor,
        )
        .toList(growable: false);
  }

  @override
  Future<void> removePhoneFactor(String factorId) async {
    accountSecurityFactors = accountSecurityFactors
        .where((factor) => factor.id != factorId)
        .toList(growable: false);
  }

  @override
  Future<void> updateAccountProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    updatedProfileFirstName = firstName;
    updatedProfileLastName = lastName;
    updatedProfileEmail = email;
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    profilePhotoUploads++;
    return uploadedProfilePhotoUrl;
  }

  @override
  Future<String?> loadProfilePhotoUrl(String? avatarPath) async {
    requestedAvatarPath = avatarPath;
    return avatarPath == null ? null : uploadedProfilePhotoUrl;
  }

  @override
  Future<ScanResult> analyzeAndSave(
    String type,
    String input, {
    bool useAi = false,
    bool useUrlReputation = false,
    String? notificationIdempotencyKey,
  }) async {
    serverAnalysisRequests++;
    if (useAi) aiProviderAnalysisRequests++;
    if (useUrlReputation) urlReputationRequests++;
    if (scanError case final error?) throw error;
    final result = analysisResult;
    scanHistory.insert(
      0,
      ScanHistoryEntry(
        id: 'scan-${scanHistory.length}',
        scanType: type,
        riskLevel: result.level,
        classification: result.classification,
        confidence: result.confidence,
        indicators: result.indicators,
        createdAt: DateTime.now(),
        analysisSummary: result.summary,
        recommendedActions: result.recommendedActions,
        analysisModulesStatus: result.analysisModulesStatus,
        confidenceReasons: result.confidenceReasons,
        analysisModules: result.analysisModules,
      ),
    );
    return result;
  }

  @override
  Future<String> chatSafetyAssistant(
    List<AssistantChatMessage> messages,
  ) async {
    assistantChatRequests++;
    lastAssistantConversation = List.unmodifiable(messages);
    return assistantReply;
  }

  @override
  Future<TrustedExampleSubmissionResult> submitTrustedExample({
    required String contentType,
    required String content,
    required String submittedLabel,
    String? scanRecordId,
  }) async => const TrustedExampleSubmissionResult(
    status: 'pending',
    submissionId: '00000000-0000-4000-8000-000000000001',
    message: 'Submitted for review.',
  );

  @override
  Future<List<TrustedExampleStatus>> loadMyTrustedExamples() async =>
      trustedExampleStatuses;

  @override
  Future<List<TrustedReviewSubmission>> loadTrustedReviewQueue({
    int limit = 30,
  }) async => trustedReviewQueue;

  @override
  Future<void> reviewTrustedExample({
    required String submissionId,
    required String decision,
    required String verificationMethod,
    required String evidenceReference,
    String? notes,
  }) async {}

  @override
  Future<void> resolveTrustedDispute({
    required String submissionId,
    required String decision,
    required String evidenceReference,
  }) async {}

  @override
  Future<List<TrustedDatasetVersion>> loadTrustedDatasetVersions() async =>
      trustedDatasetVersions;

  @override
  Future<TrustedDatasetEvaluationResult> evaluateTrustedDatasetVersion(
    String datasetVersionId,
  ) async =>
      const TrustedDatasetEvaluationResult(status: 'failed', evaluation: {});

  @override
  Future<void> releaseTrustedDatasetVersion(String datasetVersionId) async {}

  @override
  Stream<List<SecurityAlert>> watchAlerts() =>
      alertStream ?? Stream.value(alerts);

  @override
  Future<void> markAlertRead(String alertId) async {}

  @override
  Future<FamilyGroup?> loadFamily() async {
    familyLoadRequests++;
    if (failNextFamilyLoad) {
      failNextFamilyLoad = false;
      throw Exception('Temporary family refresh failure.');
    }
    return family;
  }

  @override
  Future<void> createFamily(String name) async {
    family = FamilyGroup(
      id: 'family-1',
      name: name,
      ownerId: 'owner-1',
      isOwner: true,
      shareReports: true,
      members: const [
        FamilyMember(
          userId: 'owner-1',
          displayName: 'Family owner',
          isOwner: true,
        ),
      ],
      pendingInvites: const [],
      reports: const [],
    );
  }

  @override
  Future<FamilyInviteCode> createFamilyInvite(String email) async =>
      inviteCode ??
      const FamilyInviteCode(
        invitationCode:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

  @override
  Future<void> revokeFamilyInvite(String email) async {}

  @override
  Future<void> acceptFamilyInvite(String token) async {}

  @override
  Future<void> removeFamilyMember(String userId) async {}

  @override
  Future<void> leaveFamily() async {
    family = null;
  }

  @override
  Future<void> deleteFamily() async {
    family = null;
  }

  @override
  Future<void> setFamilySharing(bool enabled) async {}

  @override
  Future<void> submitScamReport({
    required String category,
    required String description,
    required bool shareWithFamily,
    String? indicator,
  }) async {
    lastReportedIndicator = indicator;
  }

  @override
  Future<void> seedFamilyThreatReports() async {}

  @override
  Future<void> deleteScanHistory() async => scanHistory.clear();
}
