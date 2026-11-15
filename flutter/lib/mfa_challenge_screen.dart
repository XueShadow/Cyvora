import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'dashboard/dashboard_repository.dart';

typedef PhoneMfaFactorOption = ({String id, String label});

class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({
    required this.factors,
    required this.onRequestCode,
    required this.onVerifyCode,
    required this.onVerified,
    required this.onSignOut,
    super.key,
  });

  final List<PhoneMfaFactorOption> factors;
  final Future<String> Function(String factorId) onRequestCode;
  final Future<void> Function(String factorId, String challengeId, String code)
  onVerifyCode;
  final VoidCallback onVerified;
  final Future<void> Function() onSignOut;

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  String? _selectedFactorId;
  String? _challengeId;
  String? _error;
  bool _isSending = true;
  bool _isVerifying = false;
  bool _isSigningOut = false;
  DateTime? _resendAvailableAt;
  Timer? _cooldownTimer;

  static const _resendCooldown = Duration(seconds: 30);

  bool get _isResendBlocked =>
      _resendAvailableAt != null &&
      DateTime.now().isBefore(_resendAvailableAt!);

  int get _resendSeconds {
    final availableAt = _resendAvailableAt;
    if (availableAt == null) return 0;
    final remaining = availableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.factors.isNotEmpty) {
      _selectedFactorId = widget.factors.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    } else {
      _isSending = false;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final factorId = _selectedFactorId;
    if (factorId == null) return;
    if (_challengeId != null && _isResendBlocked) return;
    setState(() {
      _isSending = true;
      _error = null;
      _challengeId = null;
    });
    try {
      final challengeId = await widget.onRequestCode(factorId);
      if (mounted) {
        setState(() {
          _challengeId = challengeId;
          _codeController.clear();
        });
        _startResendCooldown();
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    final factorId = _selectedFactorId;
    final challengeId = _challengeId;
    if (factorId == null || challengeId == null) return;
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await widget.onVerifyCode(
        factorId,
        challengeId,
        _codeController.text.trim(),
      );
      if (mounted) widget.onVerified();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _startResendCooldown() {
    _resendAvailableAt = DateTime.now().add(_resendCooldown);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_isResendBlocked) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
      setState(() {});
    });
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = mfaErrorMessage(error);
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFactors = widget.factors.isNotEmpty;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sms_outlined,
                      size: 52,
                      color: Color(0xFF34E89B),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasFactors
                          ? 'Verify it’s you'
                          : 'Additional verification required',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasFactors
                          ? 'Enter the SMS code to finish signing in.'
                          : 'This account requires a second factor, but no '
                                'supported phone factor is available. Sign out '
                                'and contact support for help restoring access.',
                      textAlign: TextAlign.center,
                    ),
                    if (hasFactors) ...[
                      const SizedBox(height: 20),
                      if (widget.factors.length > 1)
                        DropdownButtonFormField<String>(
                          key: const Key('login-mfa-factor'),
                          initialValue: _selectedFactorId,
                          decoration: const InputDecoration(
                            labelText: 'Phone factor',
                          ),
                          items: widget.factors
                              .map(
                                (factor) => DropdownMenuItem(
                                  value: factor.id,
                                  child: Text(factor.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _isSending || _isVerifying
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _selectedFactorId = value);
                                  _sendCode();
                                },
                        )
                      else
                        Text(
                          'A code will be sent to '
                          '${widget.factors.first.label}.',
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          key: const Key('login-mfa-code'),
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enabled: !_isSending && !_isVerifying,
                          decoration: const InputDecoration(
                            labelText: 'Six-digit SMS code',
                          ),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value ?? '')
                              ? null
                              : 'Enter the six-digit SMS code',
                        ),
                      ),
                      if (_isSending) ...[
                        const SizedBox(height: 8),
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 8),
                        const Text(
                          'Sending verification code…',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      TextButton(
                        onPressed:
                            _isSending || _isVerifying || _isResendBlocked
                            ? null
                            : _sendCode,
                        child: Text(
                          _isResendBlocked
                              ? 'Resend in ${_resendSeconds}s'
                              : 'Resend code',
                        ),
                      ),
                      FilledButton(
                        key: const Key('verify-login-mfa'),
                        onPressed:
                            _isSending || _isVerifying || _challengeId == null
                            ? null
                            : _verifyCode,
                        child: _isVerifying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Verify and continue'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Could not verify your account: $_error',
                        key: const Key('login-mfa-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isSigningOut ? null : _signOut,
                      child: Text(_isSigningOut ? 'Signing out…' : 'Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
