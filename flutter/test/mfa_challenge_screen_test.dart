import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyvora_mobile/mfa_challenge_screen.dart';

void main() {
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
          onVerified: () {},
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
}
