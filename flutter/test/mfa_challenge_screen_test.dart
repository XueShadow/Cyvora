import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyvora_mobile/features/authentication/views/mfa_challenge_screen.dart';

void main() {
  testWidgets('a privileged account without a verified factor stays blocked', (
    WidgetTester tester,
  ) async {
    var requestedCode = false;
    var didVerify = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MfaChallengeScreen(
          factors: const [],
          onRequestCode: (factorId) async {
            requestedCode = true;
            return 'challenge';
          },
          onVerifyCode: (factorId, challengeId, code) async {
            didVerify = true;
          },
          onVerified: () async {},
          onSignOut: () async {},
        ),
      ),
    );

    expect(
      find.textContaining('no verified factor is available'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('verify-login-mfa')), findsNothing);
    expect(requestedCode, isFalse);
    expect(didVerify, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TOTP sign-in prompts for an authenticator app code', (
    WidgetTester tester,
  ) async {
    String? requestedFactor;

    await tester.pumpWidget(
      MaterialApp(
        home: MfaChallengeScreen(
          factors: [
            (id: 'totp-factor', label: 'authenticator app', isPhone: false),
          ],
          onRequestCode: (factorId) async {
            requestedFactor = factorId;
            return 'totp-challenge';
          },
          onVerifyCode: (factorId, challengeId, code) async {},
          onVerified: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(requestedFactor, 'totp-factor');
    expect(find.text('Open authenticator app to get a code.'), findsOneWidget);
    expect(find.text('Six-digit authenticator code'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('waits for post-verification assurance recheck', (
    WidgetTester tester,
  ) async {
    var sessionRechecked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MfaChallengeScreen(
          factors: const [
            (id: 'totp-factor', label: 'authenticator app', isPhone: false),
          ],
          onRequestCode: (factorId) async => 'challenge',
          onVerifyCode: (factorId, challengeId, code) async {},
          onVerified: () async {
            await Future<void>.delayed(Duration.zero);
            sessionRechecked = true;
          },
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-mfa-code')), '123456');
    await tester.tap(find.byKey(const Key('verify-login-mfa')));
    await tester.pumpAndSettle();

    expect(sessionRechecked, isTrue);
  });

  testWidgets('blocks resend until the cooldown expires', (
    WidgetTester tester,
  ) async {
    var codeRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MfaChallengeScreen(
          factors: const [
            (id: 'totp-factor', label: 'authenticator app', isPhone: false),
          ],
          onRequestCode: (factorId) async {
            codeRequests++;
            return 'challenge-$codeRequests';
          },
          onVerifyCode: (factorId, challengeId, code) async {},
          onVerified: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final resendButton = find.byWidgetPredicate((widget) {
      if (widget is! TextButton) return false;
      final child = widget.child;
      return child is Text && (child.data?.startsWith('Resend in') ?? false);
    });
    expect(codeRequests, 1);
    expect(resendButton, findsOneWidget);
    expect(tester.widget<TextButton>(resendButton).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
