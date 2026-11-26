import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cyvora_mobile/features/authentication/models/authentication_repository.dart';
import 'package:cyvora_mobile/features/authentication/presenters/auth_presenter.dart';
import 'package:cyvora_mobile/features/authentication/views/auth_screen.dart';

void main() {
  testWidgets('ignores repeated keyboard submission while login is pending', (
    WidgetTester tester,
  ) async {
    final repository = _PendingSignInRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(presenter: AuthPresenter(repository)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'StrongPass123!',
    );
    await tester.showKeyboard(find.byKey(const Key('password-field')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repository.signInCalls, 1);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.signInCalls, 1);

    repository.signInCompleter.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a safe failure and clears the login loading state', (
    WidgetTester tester,
  ) async {
    final repository = _PendingSignInRepository(
      failWith: StateError('sensitive provider response'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(presenter: AuthPresenter(repository)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'StrongPass123!',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-auth')));
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    expect(
      find.text('Authentication could not be completed. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive provider response'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('submit-auth'))).onPressed,
      isNotNull,
    );
  });
}

class _PendingSignInRepository implements AuthenticationRepository {
  _PendingSignInRepository({this.failWith});

  final Object? failWith;
  final signInCompleter = Completer<void>();
  int signInCalls = 0;

  @override
  Stream<AuthenticationState> watchAuthState() =>
      const Stream<AuthenticationState>.empty();

  @override
  AuthenticationState get currentAuthState =>
      const AuthenticationState(event: AuthenticationEvent.initialSession);

  @override
  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  }) async => const MfaSessionState(requiresChallenge: false, factors: []);

  @override
  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) async => 'challenge';

  @override
  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  }) async => true;

  @override
  Future<void> signIn({required String email, required String password}) {
    signInCalls++;
    final failure = failWith;
    if (failure != null) return Future<void>.error(failure);
    return signInCompleter.future;
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}
}
