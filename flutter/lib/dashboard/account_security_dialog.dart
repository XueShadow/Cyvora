import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'dashboard_repository.dart';

class AccountSecurityDialog extends StatefulWidget {
  const AccountSecurityDialog({
    required this.repository,
    required this.email,
    super.key,
  });

  final DashboardRepository repository;
  final String email;

  @override
  State<AccountSecurityDialog> createState() => _AccountSecurityDialogState();
}

class _SecuritySectionHeading extends StatelessWidget {
  const _SecuritySectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AccountSecurityDialogState extends State<AccountSecurityDialog> {
  final _phoneController = TextEditingController();
  final _setupCodeController = TextEditingController();
  final _removalCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  List<AccountSecurityFactor> _factors = const [];
  PhoneFactorChallenge? _setupChallenge;
  PhoneFactorChallenge? _removalChallenge;
  String? _pendingFactorId;
  String? _pendingFactorName;
  String? _removingFactorId;
  bool _removalVerified = false;
  bool _isLoading = true;
  bool _isWorking = false;
  Object? _error;
  String? _message;
  bool _showPasswordForm = false;
  DateTime? _setupResendAvailableAt;
  DateTime? _removalResendAvailableAt;
  Timer? _cooldownTimer;

  static const _resendCooldown = Duration(seconds: 30);

  bool _isResendBlocked(DateTime? availableAt) =>
      availableAt != null && DateTime.now().isBefore(availableAt);

  int _resendSeconds(DateTime? availableAt) {
    if (availableAt == null) return 0;
    final remaining = availableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldown({required bool setup}) {
    final availableAt = DateTime.now().add(_resendCooldown);
    setState(() {
      if (setup) {
        _setupResendAvailableAt = availableAt;
      } else {
        _removalResendAvailableAt = availableAt;
      }
    });
    _cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final setupBlocked = _isResendBlocked(_setupResendAvailableAt);
      final removalBlocked = _isResendBlocked(_removalResendAvailableAt);
      if (!setupBlocked && !removalBlocked) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFactors();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _setupCodeController.dispose();
    _removalCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadFactors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final factors = await widget.repository.loadAccountSecurityFactors();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        if (_pendingFactorId == null) {
          for (final factor in factors) {
            if (factor.isPhone && !factor.isVerified) {
              _pendingFactorId = factor.id;
              _pendingFactorName = factor.friendlyName;
              break;
            }
          }
        }
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    setState(() {
      _showPasswordForm = true;
      _error = null;
      _message = null;
    });
  }

  Future<void> _updatePassword() async {
    final password = _newPasswordController.text;
    if (password.length < 12) {
      setState(() => _error = 'Use at least 12 characters for your password.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    setState(() {
      _isWorking = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.repository.updatePassword(password);
      if (mounted) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _showPasswordForm = false;
          _message = 'Your password was changed successfully.';
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _enrollPhone() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      setState(() {
        _error = 'Enter a valid phone number in international format, such as +14155552671.';
      });
      return;
    }

    setState(() {
      _isWorking = true;
      _error = null;
      _message = null;
    });
    try {
      final factorId = await widget.repository.enrollPhoneFactor(phone);
      if (!mounted) return;
      setState(() {
        _pendingFactorId = factorId;
        _pendingFactorName =
            'Mobile ending ${phone.substring(phone.length - 4)}';
        _phoneController.clear();
      });
      await _sendSetupCode();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _sendSetupCode() async {
    final factorId = _pendingFactorId;
    if (factorId == null) return;
    if (_setupChallenge != null && _isResendBlocked(_setupResendAvailableAt)) {
      return;
    }
    setState(() {
      _isWorking = true;
      _error = null;
      _message = null;
    });
    try {
      final challenge = await widget.repository.sendPhoneFactorChallenge(
        factorId,
      );
      if (mounted) {
        setState(() {
          _setupChallenge = challenge;
          _setupCodeController.clear();
          _message = 'A verification code was sent by SMS.';
        });
        _startCooldown(setup: true);
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _verifySetupCode() async {
    final factorId = _pendingFactorId;
    final challenge = _setupChallenge;
    if (factorId == null || challenge == null) return;
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      setState(
        () => _error = 'This verification code expired. Request a new code.',
      );
      return;
    }
    final code = _setupCodeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit SMS code.');
      return;
    }

    setState(() {
      _isWorking = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.repository.verifyPhoneFactorChallenge(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _pendingFactorId = null;
        _pendingFactorName = null;
        _setupChallenge = null;
        _setupCodeController.clear();
        _message = 'SMS two-factor authentication is enabled.';
      });
      await _loadFactors();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _cancelPendingSetup() async {
    final factorId = _pendingFactorId;
    if (factorId == null) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await widget.repository.removePhoneFactor(factorId);
      if (!mounted) return;
      setState(() {
        _pendingFactorId = null;
        _pendingFactorName = null;
        _setupChallenge = null;
        _setupCodeController.clear();
      });
      await _loadFactors();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _beginRemoval(AccountSecurityFactor factor) async {
    setState(() {
      _removingFactorId = factor.id;
      _removalChallenge = null;
      _removalVerified = false;
      _removalCodeController.clear();
    });
    await _sendRemovalCode();
  }

  Future<void> _sendRemovalCode() async {
    final factorId = _removingFactorId;
    if (factorId == null) return;
    if (_removalChallenge != null &&
        _isResendBlocked(_removalResendAvailableAt)) {
      return;
    }
    setState(() {
      _isWorking = true;
      _error = null;
      _message = null;
    });
    try {
      final challenge = await widget.repository.sendPhoneFactorChallenge(
        factorId,
      );
      if (mounted) {
        setState(() {
          _removalChallenge = challenge;
          _removalVerified = false;
          _removalCodeController.clear();
          _message = 'A verification code was sent to this phone.';
        });
        _startCooldown(setup: false);
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _verifyRemovalCode() async {
    final factorId = _removingFactorId;
    final challenge = _removalChallenge;
    if (factorId == null || challenge == null) return;
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      setState(
        () => _error = 'This verification code expired. Request a new code.',
      );
      return;
    }
    final code = _removalCodeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit SMS code.');
      return;
    }

    setState(() {
      _isWorking = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.repository.verifyPhoneFactorChallenge(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );
      if (!mounted) return;
      setState(() => _removalVerified = true);
      await _removeVerifiedFactor();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _removeVerifiedFactor() async {
    final factorId = _removingFactorId;
    if (factorId == null) return;
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await widget.repository.removePhoneFactor(factorId);
      if (!mounted) return;
      setState(() {
        _removingFactorId = null;
        _removalChallenge = null;
        _removalVerified = false;
        _removalCodeController.clear();
        _message = 'The phone factor was removed.';
      });
      await _loadFactors();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifiedPhoneFactors = _factors
        .where((factor) => factor.isPhone && factor.isVerified)
        .toList(growable: false);
    final otherVerifiedFactors = _factors
        .where((factor) => !factor.isPhone && factor.isVerified)
        .toList(growable: false);

    return AlertDialog(
      title: const Text('Account security'),
      scrollable: true,
      content: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Signed in as ${widget.email}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _SecuritySectionHeading(
              icon: Icons.lock_outline_rounded,
              title: 'Password',
            ),
            const SizedBox(height: 10),
            if (_showPasswordForm) ...[
              TextField(
                key: const Key('new-password'),
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'Use at least 12 characters.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('confirm-new-password'),
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _isWorking
                        ? null
                        : () => setState(() {
                            _showPasswordForm = false;
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                          }),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('save-new-password'),
                    onPressed: _isWorking ? null : _updatePassword,
                    child: const Text('Save password'),
                  ),
                ],
              ),
            ] else
              OutlinedButton.icon(
                key: const Key('change-password'),
                onPressed: _isWorking ? null : _requestPasswordReset,
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Change password'),
              ),
            const Divider(height: 32),
            _SecuritySectionHeading(
              icon: Icons.sms_outlined,
              title: 'SMS two-factor authentication',
            ),
            const SizedBox(height: 8),
            Text(
              'Add a phone number to receive a one-time code when signing in. '
              'An SMS provider must be enabled in Supabase Auth.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_error != null) ...[
                Text(
                  'Could not complete the security request: $_error',
                  key: const Key('account-security-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 10),
              ],
              if (_message != null) ...[
                Text(
                  _message!,
                  key: const Key('account-security-message'),
                  style: const TextStyle(color: Color(0xFF34E89B)),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                verifiedPhoneFactors.isEmpty && otherVerifiedFactors.isEmpty
                    ? 'Two-factor authentication is off'
                    : 'Two-factor authentication is on',
                key: const Key('account-security-status'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final factor in verifiedPhoneFactors)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sms_outlined),
                  title: Text(factor.friendlyName ?? 'Phone number'),
                  subtitle: const Text('Verified by SMS'),
                  trailing: TextButton(
                    onPressed: _isWorking ? null : () => _beginRemoval(factor),
                    child: const Text('Remove'),
                  ),
                ),
              if (otherVerifiedFactors.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Another MFA method is enabled. This app can manage SMS '
                    'factors only.',
                  ),
                ),
              if (_removingFactorId != null) ...[
                const Divider(),
                Text(
                  _removalVerified
                      ? 'Verification complete. Remove this phone factor?'
                      : 'Enter the code sent to confirm removal.',
                ),
                if (!_removalVerified) ...[
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('remove-sms-code'),
                    controller: _removalCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Six-digit SMS code',
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _isWorking ||
                            _isResendBlocked(_removalResendAvailableAt)
                        ? null
                        : _sendRemovalCode,
                    child: Text(
                      _isResendBlocked(_removalResendAvailableAt)
                          ? 'Resend in ${_resendSeconds(_removalResendAvailableAt)}s'
                          : 'Resend code',
                    ),
                  ),
                ],
                Row(
                  children: [
                    TextButton(
                      onPressed: _isWorking
                          ? null
                          : () => setState(() {
                              _removingFactorId = null;
                              _removalChallenge = null;
                              _removalVerified = false;
                            }),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _isWorking
                          ? null
                          : _removalVerified
                          ? _removeVerifiedFactor
                          : _verifyRemovalCode,
                      child: Text(
                        _removalVerified ? 'Remove phone' : 'Verify and remove',
                      ),
                    ),
                  ],
                ),
              ],
              if (_pendingFactorId != null) ...[
                const Divider(),
                Text(
                  'Finish setup for ${_pendingFactorName ?? 'your phone'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_setupChallenge == null)
                  FilledButton.tonal(
                    onPressed: _isWorking ? null : _sendSetupCode,
                    child: const Text('Send SMS code'),
                  )
                else ...[
                  TextField(
                    key: const Key('setup-sms-code'),
                    controller: _setupCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Six-digit SMS code',
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            _isWorking ||
                                _isResendBlocked(_setupResendAvailableAt)
                            ? null
                            : _sendSetupCode,
                        child: Text(
                          _isResendBlocked(_setupResendAvailableAt)
                              ? 'Resend in ${_resendSeconds(_setupResendAvailableAt)}s'
                              : 'Resend code',
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _isWorking ? null : _verifySetupCode,
                        child: const Text('Verify phone'),
                      ),
                    ],
                  ),
                ],
                TextButton(
                  onPressed: _isWorking ? null : _cancelPendingSetup,
                  child: const Text('Cancel phone setup'),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('mfa-phone-number'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+14155552671',
                    helperText: 'E.164 format, e.g. +14155552671',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('start-sms-mfa'),
                  onPressed: _isWorking ? null : _enrollPhone,
                  child: Text(
                    verifiedPhoneFactors.isEmpty
                        ? 'Enable SMS 2FA'
                        : 'Add another phone',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isWorking ? null : () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
