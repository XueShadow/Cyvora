enum AuthenticationEvent { initialSession, passwordRecovery, other }

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.userMetadata,
    required this.appMetadata,
  });

  final String id;
  final String? email;
  final Map<String, dynamic> userMetadata;
  final Map<String, dynamic> appMetadata;
}

class AuthenticationState {
  const AuthenticationState({required this.event, this.user});

  final AuthenticationEvent event;
  final AuthenticatedUser? user;
}

typedef AuthenticationFactor = ({String id, String label, bool isPhone});

enum AuthenticationErrorReason {
  generic,
  invalidCredentials,
  emailNotConfirmed,
  expiredRecoveryLink,
  invalidCallback,
  rateLimited,
  networkUnavailable,
  serviceUnavailable,
  sessionExpired,
  weakPassword,
  invalidMfaCode,
  expiredMfaChallenge,
}

class MfaSessionState {
  const MfaSessionState({
    required this.requiresChallenge,
    required this.factors,
  });

  final bool requiresChallenge;
  final List<AuthenticationFactor> factors;

  bool get hasSupportedFactor => factors.isNotEmpty;
}

abstract interface class AuthenticationRepository {
  Stream<AuthenticationState> watchAuthState();

  AuthenticationState get currentAuthState;

  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  });

  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  });

  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  });

  Future<void> signOut();

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> resendConfirmationEmail(String email);

  Future<void> requestPasswordReset(String email);

  Future<void> updatePassword(String password);
}

class AuthenticationException implements Exception {
  const AuthenticationException(
    this.message, {
    this.reason = AuthenticationErrorReason.generic,
  });

  final String message;
  final AuthenticationErrorReason reason;

  @override
  String toString() => message;
}

class AuthenticationValidation {
  AuthenticationValidation._();

  static final _passwordSymbolPattern = RegExp(
    r'''[!@#$%^&*()_+\-=\[\]{};':"|<>?,./`~\\]''',
  );
  static final _emailPattern = RegExp(
    r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  static bool isValidEmail(String email) => _emailPattern.hasMatch(email);

  static bool containsSymbol(String password) =>
      _passwordSymbolPattern.hasMatch(password);

  static bool hasStrongPassword(String password) {
    final characterTypeCount = [
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'[0-9]').hasMatch(password),
      containsSymbol(password),
    ].where((hasType) => hasType).length;

    return password.runes.length >= 12 && characterTypeCount >= 3;
  }
}
