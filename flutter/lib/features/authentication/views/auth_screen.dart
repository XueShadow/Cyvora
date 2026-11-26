import 'package:material_ui/material_ui.dart';

import '../../../core/theme/cyvora_theme.dart';
import '../../../core/widgets/cyvora_components.dart';
import '../../../core/widgets/cyvora_logo.dart';
import '../models/authentication_repository.dart';
import '../presenters/auth_presenter.dart';

const _navy = CyvoraColors.text;
const _blue = CyvoraColors.light;
const _muted = CyvoraColors.secondaryText;
const _green = CyvoraColors.electric;
const _authCardColor = CyvoraColors.surface;
const _authInput = CyvoraColors.surfaceSecondary;
const _authBorder = CyvoraColors.border;
const _termsSections = [
  (
    '1. About this service',
    'Cyvora is operated by Ji Monsales. For support or questions about these '
        'terms, contact jimonsales71@gmail.com. These terms apply when you '
        'create or use a Cyvora account.',
  ),
  (
    '2. What Cyvora does',
    'Cyvora is an evolving family-safety application. Features and information '
        'may change. The app is not an emergency, medical, legal, or '
        'professional security service. It does not monitor situations or '
        'guarantee that information, alerts, or recommendations are complete, '
        'accurate, timely, or delivered. Do not rely on Cyvora when someone '
        'may be in immediate danger; contact local emergency services.',
  ),
  (
    '3. Your account',
    'Provide accurate account details and keep your sign-in credentials '
        'confidential. You are responsible for activity through your account. '
        'Tell us promptly at jimonsales71@gmail.com if you suspect '
        'unauthorized access. Do not use another person’s account without '
        'permission.',
  ),
  (
    '4. Acceptable use',
    'Use Cyvora lawfully and respectfully. Do not attempt to access accounts '
        'or systems without authorization, disrupt or compromise the service, '
        'misuse another person’s information, or use the app to threaten, '
        'harass, or harm anyone. Do not submit information you have no right '
        'to provide.',
  ),
  (
    '5. Availability and third parties',
    'The service may be unavailable, changed, or discontinued, including for '
        'maintenance or security reasons. Sign-in and account email depend on '
        'third-party providers, including Supabase and configured email and SMS '
        'providers, whose services are subject to their own terms and policies.',
  ),
  (
    '6. Suspension and account closure',
    'You may stop using Cyvora and request account deletion by emailing '
        'jimonsales71@gmail.com. We may restrict or suspend access when '
        'reasonably needed to protect users, investigate suspected misuse, '
        'secure the service, or comply with law. We will handle account and '
        'data requests under the Privacy Policy and applicable law.',
  ),
  (
    '7. Disclaimers and liability',
    'To the extent permitted by applicable law, Cyvora is provided on an '
        '“as available” basis and without a guarantee that it will be '
        'uninterrupted or error-free. Nothing in these terms removes rights '
        'or remedies that cannot lawfully be excluded. Any limitation of '
        'liability must be interpreted subject to applicable law.',
  ),
  (
    '8. Changes and governing law',
    'We may revise these terms as the service changes. Material changes will '
        'be identified by an updated policy version recorded with your '
        'signup consent. These terms are governed by the laws of the '
        'Philippines, subject to mandatory consumer protections and rules on '
        'jurisdiction.',
  ),
];
const _privacySections = [
  (
    '1. Who is responsible',
    'Cyvora is operated by Ji Monsales. Contact jimonsales71@gmail.com for '
        'privacy questions or requests. This policy explains how Cyvora '
        'handles account information and should be read consistently with '
        'the Philippines Data Privacy Act of 2012 (Republic Act No. 10173) '
        'and other applicable laws.',
  ),
  (
    '2. Information collected',
    'When you register, we collect your first name, last name, and email '
        'address. Supabase Auth processes your password for sign-in and stores '
        'it as a hash; the Cyvora operator does not have access to your '
        'readable password. We also record signup consent timestamps and '
        'policy-version labels in your Auth account metadata. If you choose '
        'SMS two-factor authentication, your phone number is stored in '
        'Supabase Auth and used to send verification codes. Cyvora stores '
        'scan dates, types, server classifications, risk levels, confidence, '
        'warning indicators, normalized analysis-module evidence, module statuses, '
        'and recommended actions, but not the original message, URL, or screenshot. '
        'URL checks send the hostname to Cloudflare DNS over HTTPS to resolve '
        'public DNS and may connect to the validated public address for a TLS '
        'handshake; '
        'Cyvora does not fetch submitted pages or follow redirects. Optional AI-provider '
        'analysis requires an explicit per-scan choice; minimized content and '
        'normalized findings are sent through Cyvora’s server to the first '
        'configured AI provider that responds. Providers may include Google '
        'Gemini, Groq, OpenRouter, Mistral, Cloudflare Workers AI, SambaNova, '
        'Cohere, NVIDIA NIM, Z.AI, and Hugging Face Inference Providers. Each '
        'provider processes data under its '
        'own terms and retention practices. On Android and iOS, screenshot text '
        'extraction runs on-device; the selected image is not uploaded. If '
        'AI-provider analysis is selected, extracted text may be minimized and '
        'sent to a configured provider. Optional URL reputation checks require '
        'separate per-scan consent. The submitted URL, including its path and '
        'query but not its fragment, is sent to configured providers: URLhaus, '
        'Google Safe Browsing, AlienVault OTX, PhishTank, urlscan.io, ThreatFox, '
        'VirusTotal, and Pulsedive. The OpenPhish community feed is checked locally. '
        'urlscan.io receives a private scan submission; private visibility does '
        'not eliminate provider retention. Provider terms and limits apply. '
        'External matches are shown as suspicious and do not alone produce a '
        'malicious verdict. If you '
        'submit a scam report, its category and description are stored in '
        'Supabase. An optional URL or domain indicator is stored only as a '
        'normalized hash and remains pending review. Family groups store a group name, member '
        'names, and invitation email addresses. Scam reports are shared with '
        'family only when the report author chooses to share them. Invitation '
        'codes are stored as hashes and expire after seven days. '
        'Optional Notification Protection is Android-only and requires a '
        'separate in-app opt-in and Android notification access. While both '
        'are enabled, Cyvora reads notification titles and previews only from '
        'supported messaging apps you select. Obvious one-time codes, login '
        'or verification codes, passwords, passcodes, and PIN-like previews '
        'are filtered before storage, but automated filters are not perfect. '
        'Eligible previews are encrypted on the device, kept for the selected '
        'one, seven, or thirty days, and deleted when monitoring is disabled '
        'or their source app is deselected. Notification content is not sent '
        'automatically; it is sent for analysis only if you choose Scan for a '
        'specific preview. Optional AI processing still requires its separate '
        'per-scan choice. Manual scanning does not require notification access.',
  ),
  (
    '3. Why we use it',
    'We use account details to create and manage your account, authenticate '
        'you, send confirmation or other account-related email, protect the '
        'service, display scan history and in-app alerts, manage family groups, '
        'create shareable family invitation codes, and respond to support, '
        'privacy, and security requests. If you enable SMS two-factor '
        'authentication, Supabase Auth and its configured SMS provider process '
        'your phone number and deliver verification codes. The server applies configurable scam '
        'rules, network checks, and reviewed local threat indicators to each scan. When you choose '
        'AI-provider analysis, minimized content and findings are sent to the '
        'first configured provider that responds; emails, phone numbers, '
        'numeric codes, URL query values, and fragments are redacted where '
        'applicable. If you separately choose URL reputation checks, the '
        'submitted URL (without its fragment) is sent to configured reputation '
        'providers and a private urlscan.io scan may be submitted. The OpenPhish '
        'feed is checked locally. Provider terms, processing locations, and '
        'retention practices differ. '
        'We do not use account details for advertising in the current app.',
  ),
  (
    '4. Processing basis',
    'We will process personal information only as permitted by applicable '
        'law, for the purposes described here and on an appropriate lawful '
        'basis. Choosing AI-provider analysis is an explicit per-scan choice '
        'to transmit minimized content and findings to a configured third-party '
        'AI provider. Enabling SMS two-factor authentication sends your phone '
        'number and verification codes through Supabase Auth and its configured '
        'SMS provider. Choosing URL reputation is a separate, explicit per-scan '
        'choice to transmit the URL to configured third-party reputation '
        'services and may submit it to urlscan.io privately. Google Safe '
        'Browsing is configured only for eligible non-commercial use. The '
        'operator must confirm '
        'and document the specific lawful bases for each purpose before '
        'publishing this policy.',
  ),
  (
    '5. Service providers and network processing',
    'Supabase provides authentication and stores account information for '
        'Cyvora, including scan-result metadata, family data, reports, and '
        'alerts, and invited email addresses with hashes of invitation codes. '
        'Family invitations are shared manually and are not emailed by Cyvora. '
        'Supabase Auth email delivery may also process account email. If you '
        'enable phone MFA, Supabase Auth and its configured SMS provider '
        'process your phone number and send verification messages; provider '
        'terms, processing locations, and retention practices apply. If you '
        'choose AI-provider analysis, the configured provider that first '
        'responds receives minimized content and normalized findings through '
        'the Supabase Edge Function. Providers are tried in configured order '
        'when credentials are available; provider terms, quotas, processing '
        'locations, and retention practices vary. '
        'For URL analysis, the backend may resolve the submitted hostname and '
        'connect to its public address for TLS validation; it does not fetch '
        'the page or follow redirects. Cyvora stores no raw scan input. Optional '
        'indicator reports store normalized hashes and are not used as confirmed '
        'threats until reviewed. On-device text '
        'recognition is provided by Google ML Kit and does not send screenshot '
        'contents to Google for this app feature. When explicitly selected, '
        'URL reputation checks send the URL (excluding its fragment) to '
        'configured providers; OpenPhish is checked against a locally fetched '
        'community feed, and urlscan.io receives a private submission. Provider '
        'retention and processing are governed by their own terms. Supabase and configured email '
        'and SMS delivery are subject to their own terms and policies.',
  ),
  (
    '6. Retention and deletion',
    'Scan-result records can be deleted in Profile. Scam reports and account, '
        'family, and invitation records are kept while needed to provide the '
        'service or until a deletion request is processed. Invitation codes '
        'expire after seven days. To request account deletion or erasure, email '
        'jimonsales71@gmail.com from your account email where possible. We may '
        'ask for reasonable verification. We will review the request under '
        'applicable law; limited information may remain where required for '
        'legal obligations, security, or dispute resolution. Supabase backups '
        'may persist for a limited time under its retention practices.',
  ),
  (
    '7. Your privacy rights',
    'Subject to applicable law and its exceptions, you may ask to be informed '
        'about processing, access or correct your information, object to or '
        'request blocking or erasure of certain processing, and exercise '
        'other rights available under the Philippines Data Privacy Act, '
        'including data portability where applicable. Contact '
        'jimonsales71@gmail.com to make a request or raise a concern. You may '
        'also contact the National Privacy Commission of the Philippines.',
  ),
  (
    '8. Security',
    'We and our service providers use administrative, organizational, and '
        'technical measures intended to protect personal information. No '
        'internet service can guarantee absolute security. Use a unique '
        'password, keep it private, and tell us promptly if you suspect '
        'unauthorized account access.',
  ),
  (
    '9. Children and policy updates',
    'This policy will be updated when Cyvora begins collecting additional '
        'information or changes its purposes. The current signup flow does '
        'not request information about children. Before introducing features '
        'involving children or their information, the operator must set '
        'appropriate age, parental-consent, and safety requirements. Cyvora '
        'will update this policy when its data practices or applicable '
        'requirements materially change. Contact the operator with questions '
        'about how this policy applies to your account.',
  ),
];

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.supabaseConfigured = true, this.presenter});

  final bool supabaseConfigured;
  final AuthPresenter? presenter;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isPasswordVisible = false;
  bool _isBusy = false;
  String? _confirmationEmail;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    if (!_formKey.currentState!.validate()) return;
    if (!widget.supabaseConfigured) {
      _showMessage(
        'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to sign in.',
      );
      return;
    }
    final presenter = widget.presenter;
    if (presenter == null) {
      _showMessage('Authentication services are unavailable.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final email = _emailController.text.trim();
      final result = await presenter.submit(
        creatingAccount: _isCreatingAccount,
        email: email,
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      if (!result.succeeded) {
        _showMessage(result.errorMessage!);
      } else if (result.confirmationEmail != null && mounted) {
        setState(() => _confirmationEmail = result.confirmationEmail);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resendConfirmationEmail(String email) async {
    if (_isBusy) return;
    if (!widget.supabaseConfigured) {
      _showMessage(
        'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to resend confirmation.',
      );
      return;
    }
    final presenter = widget.presenter;
    if (presenter == null) {
      _showMessage('Authentication services are unavailable.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final result = await presenter.resendConfirmationEmail(email);
      if (result.succeeded) {
        _showMessage(
          'Confirmation email request accepted. Check your inbox and spam folder.',
        );
      } else {
        _showMessage(result.errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isBusy) return;
    if (!widget.supabaseConfigured) {
      _showMessage(
        'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to reset a password.',
      );
      return;
    }

    final presenter = widget.presenter;
    if (presenter == null) {
      _showMessage('Authentication services are unavailable.');
      return;
    }

    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    setState(() => _isBusy = true);
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reset your password'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Send link'),
            ),
          ],
        ),
      );
      if (email == null) return;
      final normalizedEmail = email.trim();
      if (!AuthenticationValidation.isValidEmail(normalizedEmail)) {
        _showMessage('Enter a valid email address to reset your password.');
        return;
      }

      final result = await presenter.requestPasswordReset(normalizedEmail);
      if (result.succeeded) {
        _showMessage(
          'If an account exists for this address, follow the reset instructions if you receive an email.',
        );
      } else {
        _showMessage(result.errorMessage!);
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _selectMode(bool createAccount) {
    if (_isBusy || _isCreatingAccount == createAccount) return;
    setState(() {
      _isCreatingAccount = createAccount;
      _formKey.currentState?.reset();
      _firstNameController.clear();
      _lastNameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _returnToLogin() {
    setState(() {
      _confirmationEmail = null;
      _isCreatingAccount = false;
      _firstNameController.clear();
      _lastNameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final confirmationEmail = _confirmationEmail;
    if (confirmationEmail != null) {
      return EmailConfirmationScreen(
        email: confirmationEmail,
        onBackToLogin: _returnToLogin,
        onResendConfirmation: () => _resendConfirmationEmail(confirmationEmail),
        isResending: _isBusy,
      );
    }

    return Scaffold(
      body: CyvoraBackground(
        child: FadeTransition(
          opacity: _entranceOpacity,
          child: Stack(
            children: [
              const Positioned(
                top: -150,
                right: -100,
                child: _GlowCircle(size: 360, color: Color(0x337C3AED)),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact =
                        constraints.maxWidth < 380 ||
                        constraints.maxHeight < 940;
                    final isWide =
                        constraints.maxWidth >= 900 &&
                        constraints.maxHeight >= 560;
                    final verticalPadding = isCompact ? 16.0 : 32.0;
                    final horizontalPadding = constraints.maxWidth < 420
                        ? 16.0
                        : isWide
                        ? 40.0
                        : 28.0;

                    final content = isWide
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: Row(
                              children: [
                                const Expanded(child: _WelcomePanel()),
                                const SizedBox(width: 56),
                                SizedBox(
                                  width: 440,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _authCard(compact: isCompact),
                                      const SizedBox(height: 22),
                                      const _PrivacyNote(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _BrandHeader(compact: isCompact),
                                SizedBox(height: isCompact ? 18 : 30),
                                _authCard(compact: isCompact),
                                const SizedBox(height: 20),
                                const _PrivacyNote(),
                              ],
                            ),
                          );

                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight - verticalPadding * 2,
                        ),
                        child: Center(child: content),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 30),
      decoration: BoxDecoration(
        color: _authCardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _authBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x337C3AED),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isCreatingAccount ? 'Create your account' : 'Welcome back',
            style: const TextStyle(
              color: _navy,
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _isCreatingAccount
                ? 'Join us for a safer digital world.'
                : 'Sign in to continue.',
            style: const TextStyle(color: _muted, height: 1.45, fontSize: 14),
          ),
          SizedBox(height: compact ? 20 : 26),
          _modeTabs(),
          SizedBox(height: compact ? 20 : 24),
          AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isCreatingAccount) ...[
                    _fieldLabel('First name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('first-name-field'),
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        hintText: 'First name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Last name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('last-name-field'),
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        hintText: 'Last name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  _fieldLabel('Email address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('email-field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: _isCreatingAccount
                        ? const [AutofillHints.email]
                        : const [AutofillHints.username],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      hintText: 'you@example.com',
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!AuthenticationValidation.isValidEmail(email)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('password-field'),
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    textInputAction: _isCreatingAccount
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: _isCreatingAccount
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    onFieldSubmitted: (_) {
                      if (!_isCreatingAccount) _submit();
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      hintText: 'Enter your password',
                      suffixIcon: IconButton(
                        tooltip: _isPasswordVisible
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _navy,
                          size: 21,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (_isCreatingAccount &&
                          !AuthenticationValidation.hasStrongPassword(
                            password,
                          )) {
                        return 'Use at least 12 characters and 3 of 4 character types';
                      }
                      if (password.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (_isCreatingAccount) ...[
                    const SizedBox(height: 8),
                    _PasswordStrengthIndicator(controller: _passwordController),
                    const SizedBox(height: 18),
                    _fieldLabel('Confirm password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('confirm-password-field'),
                      controller: _confirmPasswordController,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        hintText: 'Re-enter your password',
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),
                    FormField<bool>(
                      key: const Key('policy-consent'),
                      initialValue: false,
                      validator: (accepted) => accepted == true ? null : 'Agree to the Terms and acknowledge the Privacy Policy to continue',
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                key: const Key('policy-consent-checkbox'),
                                value: field.value ?? false,
                                onChanged: (value) => field.didChange(value),
                                activeColor: _blue,
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'I agree to the ',
                                      style: TextStyle(
                                        color: _navy,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextButton(
                                      key: const Key('terms-policy-link'),
                                      onPressed: () => _showPolicy(
                                        context,
                                        title: 'Terms of Service',
                                        sections: _termsSections,
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Terms of Service'),
                                    ),
                                    const Text(
                                      ' and acknowledge the ',
                                      style: TextStyle(
                                        color: _navy,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextButton(
                                      key: const Key('privacy-policy-link'),
                                      onPressed: () => _showPolicy(
                                        context,
                                        title: 'Privacy Policy',
                                        sections: _privacySections,
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Privacy Policy'),
                                    ),
                                    const Text(
                                      '.',
                                      style: TextStyle(
                                        color: _navy,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!_isCreatingAccount) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final forgotPasswordButton = TextButton(
                  onPressed: _isBusy ? null : _sendPasswordReset,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );

                if (constraints.maxWidth < 360) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: forgotPasswordButton,
                  );
                }

                return Align(
                  alignment: Alignment.centerRight,
                  child: forgotPasswordButton,
                );
              },
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const Key('submit-auth'),
              onPressed: _isBusy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: CyvoraColors.electric,
                foregroundColor: CyvoraColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isBusy
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CyvoraColors.onPrimary,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isCreatingAccount ? 'Create Account' : 'Log In',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, size: 22),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPolicy(
    BuildContext context, {
    required String title,
    required List<(String, String)> sections,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This policy explains Cyvora’s account practices. Contact '
                  'jimonsales71@gmail.com with questions or privacy requests.',
                  style: TextStyle(color: _muted, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                for (final (heading, body) in sections) ...[
                  Text(
                    heading,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _modeTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _authInput,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _modeTab(
            'Log In',
            isSelected: !_isCreatingAccount,
            onTap: () {
              _selectMode(false);
            },
          ),
          _modeTab(
            'Create Account',
            isSelected: _isCreatingAccount,
            onTap: () {
              _selectMode(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _modeTab(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? CyvoraColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x668B5CF6),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          key: Key('tab-$label'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? _green : _muted,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _navy,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final password = value.text;
        final checks = [
          ('12+ characters', password.runes.length >= 12),
          ('Uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
          ('Lowercase letter', RegExp(r'[a-z]').hasMatch(password)),
          ('Number', RegExp(r'[0-9]').hasMatch(password)),
          ('Symbol', AuthenticationValidation.containsSymbol(password)),
        ];
        final completed = checks.where((check) => check.$2).length;
        final isStrong = AuthenticationValidation.hasStrongPassword(password);
        final color = isStrong ? _green : _muted;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: completed / checks.length,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                    color: isStrong ? _green : _blue,
                    backgroundColor: _authBorder,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isStrong ? 'Strong' : 'Not strong yet',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final (label, passed) in checks)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passed ? Icons.check_circle : Icons.circle_outlined,
                        size: 13,
                        color: passed ? _green : _muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: passed ? _navy : _muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CyvoraBrandLockup(key: const Key('brand-title'), compact: compact);
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CyvoraShieldLogo(size: 92),
          SizedBox(height: 22),
          Text(
            'CYVORA',
            style: TextStyle(
              color: CyvoraColors.text,
              fontSize: 56,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Scan. Check.\nStay Safe.',
            style: TextStyle(
              color: CyvoraColors.text,
              fontSize: 36,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: 420,
            child: Text(
              'Modern protection for your account, messages, and family.',
              style: TextStyle(
                color: CyvoraColors.secondaryText,
                fontSize: 17,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_rounded, color: _green, size: 22),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Your privacy and security are our priority',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class EmailConfirmationScreen extends StatelessWidget {
  const EmailConfirmationScreen({
    super.key,
    required this.email,
    required this.onBackToLogin,
    required this.onResendConfirmation,
    this.isResending = false,
  });

  final String email;
  final VoidCallback onBackToLogin;
  final Future<void> Function() onResendConfirmation;
  final bool isResending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CyvoraBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 380 || constraints.maxHeight < 700;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < 420 ? 16 : 28,
                  vertical: compact ? 16 : 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 32 : 64),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BrandHeader(compact: compact),
                          SizedBox(height: compact ? 18 : 30),
                          Container(
                            key: const Key('email-confirmation-screen'),
                            width: double.infinity,
                            padding: EdgeInsets.all(compact ? 22 : 32),
                            decoration: BoxDecoration(
                              color: _authCardColor,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: _authBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x667C3AED),
                                  blurRadius: 32,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: const BoxDecoration(
                                    color: CyvoraColors.deep,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mark_email_read_outlined,
                                    color: _blue,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Check your email',
                                  key: Key('email-confirmation-title'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'If email confirmation is required, check for a confirmation email at',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SelectableText(
                                  email,
                                  key: const Key('confirmation-email'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _navy,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'If you receive the confirmation email, open it and follow its link to verify your address. If no email arrives, check your spam folder or request another email below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 14,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'For secure sign-in, open the link in the same browser where you signed up.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    key: const Key('resend-confirmation'),
                                    onPressed: isResending
                                        ? null
                                        : onResendConfirmation,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _green,
                                      side: const BorderSide(
                                        color: _authBorder,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: isResending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Resend confirmation email',
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton(
                                    key: const Key('back-to-login'),
                                    onPressed: onBackToLogin,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: CyvoraColors.electric,
                                      foregroundColor: CyvoraColors.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Back to Log In',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _PrivacyNote(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
