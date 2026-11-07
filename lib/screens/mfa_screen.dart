import 'package:flutter/material.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// MFA verification screen shown after successful password login when MFA is enrolled.
class MfaVerifyScreen extends StatefulWidget {
  const MfaVerifyScreen({super.key});
  @override
  State<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends State<MfaVerifyScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  bool showRecoveryInput = false;
  final recoveryController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    recoveryController.dispose();
    super.dispose();
  }

  void _verify() {
    final store = AppScope.of(context);
    final code = codeController.text.trim();
    if (code.length != 6) {
      showFeedback(context, 'Enter the 6-digit code', isError: true);
      return;
    }
    setState(() => loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        store.verifyMfa(code);
        // Login completes — the app will rebuild to show home shell
      } catch (e) {
        if (mounted) {
          setState(() => loading = false);
          showFeedback(context, e is StateError ? e.message.toString() : 'Verification failed.', isError: true);
        }
      }
    });
  }

  void _verifyRecovery() {
    final store = AppScope.of(context);
    final code = recoveryController.text.trim();
    if (code.isEmpty) {
      showFeedback(context, 'Enter a recovery code', isError: true);
      return;
    }
    try {
      store.verifyWithRecoveryCode(code);
    } catch (e) {
      if (mounted) {
        showFeedback(context, e is StateError ? e.message.toString() : 'Invalid recovery code.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pendingUser = store.mfaPendingUser;
    final lockedOut = store.isMfaLockedOut;

    return Scaffold(
      backgroundColor: FoodieitTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: FoodieitTheme.primary,
                      borderRadius: BorderRadius.circular(FoodieitTheme.radiusXl),
                      boxShadow: FoodieitTheme.shadowMd,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.lock_person, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('Two-Factor Authentication',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('Enter the code from your authenticator app',
                            style: TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (pendingUser != null) ...[
                    BrandedCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Verify your identity',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text('Account: ${pendingUser.email}',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 24),

                          if (!showRecoveryInput) ...[
                            // Code input
                            TextField(
                              controller: codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
                              decoration: const InputDecoration(
                                labelText: '6-digit code',
                                hintText: '000000',
                                counterText: '',
                              ),
                              onSubmitted: lockedOut ? null : (_) => _verify(),
                            ),
                            const SizedBox(height: 20),

                            // Attempt info
                            if (lockedOut)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: FoodieitTheme.dangerBg,
                                  borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_clock, size: 20, color: FoodieitTheme.danger),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Account temporarily locked due to too many attempts.',
                                        style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              )
                            else
                              FilledButton(
                                onPressed: loading ? null : _verify,
                                child: loading
                                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Verify'),
                              ),

                            const SizedBox(height: 16),
                            // Resend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: lockedOut ? null : () {
                                    try {
                                      store.resendMfaCode();
                                      showFeedback(context, 'New code sent');
                                    } catch (e) {
                                      showFeedback(context, e is StateError ? e.message.toString() : 'Unable to resend.', isError: true);
                                    }
                                  },
                                  child: const Text('Resend code'),
                                ),
                              ],
                            ),

                            // Demo: show current code (never do this in production!)
                            if (store.currentMfaDemoCode != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: FoodieitTheme.warningBg,
                                  borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                                  border: Border.all(color: FoodieitTheme.warning.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.info_outline, size: 14, color: FoodieitTheme.warning),
                                        const SizedBox(width: 6),
                                        Text('SIMULATED MFA CODE (demo only)',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: FoodieitTheme.warning)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      store.currentMfaDemoCode!,
                                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: FoodieitTheme.warning, letterSpacing: 8),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('In production, this code is generated by Google Authenticator, Authy, or similar TOTP app.',
                                        style: TextStyle(fontSize: 10, color: FoodieitTheme.warning), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            // Recovery code input
                            TextField(
                              controller: recoveryController,
                              decoration: const InputDecoration(
                                labelText: 'Recovery code',
                                hintText: 'XXXXX-XXXXX',
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _verifyRecovery,
                              child: const Text('Use recovery code'),
                            ),
                          ],

                          const SizedBox(height: 16),
                          // Toggle between code and recovery
                          TextButton(
                            onPressed: () => setState(() => showRecoveryInput = !showRecoveryInput),
                            child: Text(showRecoveryInput ? 'Use authenticator code instead' : 'Use recovery code instead'),
                          ),

                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              store.cancelMfa();
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// MFA enrolment screen — shown when user opts in to MFA.
class MfaEnrolScreen extends StatefulWidget {
  const MfaEnrolScreen({super.key});
  @override
  State<MfaEnrolScreen> createState() => _MfaEnrolScreenState();
}

class _MfaEnrolScreenState extends State<MfaEnrolScreen> {
  String? secret;
  List<String>? recoveryCodes;
  bool codesAcknowledged = false;

  void _enrol() {
    final store = AppScope.of(context);
    try {
      final result = store.enrolMfa();
      setState(() {
        secret = result.secret;
        recoveryCodes = result.recoveryCodes;
      });
    } catch (e) {
      if (mounted) {
        showFeedback(context, e is StateError ? e.message.toString() : 'Unable to enrol.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final u = store.current!;

    return Scaffold(
      appBar: AppBar(title: const Text('Secure your account')),
      body: PageBody(
        children: [
          if (secret == null) ...[
            // Introduction
            BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FoodieitTheme.primaryLight,
                          borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                        ),
                        child: const Icon(Icons.shield, size: 32, color: FoodieitTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Two-Factor Authentication', style: Theme.of(context).textTheme.headlineSmall)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Add an extra layer of security to your Foodieit account. '
                      'After enrolment, you will need a code from your authenticator app '
                      '(Google Authenticator, Authy, etc.) each time you sign in.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  Text('How it works:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _StepItem(1, 'Install an authenticator app'),
                  _StepItem(2, 'Scan the QR code or enter the secret key'),
                  _StepItem(3, 'Save your recovery codes in a safe place'),
                  _StepItem(4, 'Enter the 6-digit code to verify'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _enrol,
                    icon: const Icon(Icons.lock_person),
                    label: const Text('Begin enrolment'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Secret + recovery codes
            BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Add to your authenticator app', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Scan this QR code or manually enter the secret key:',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  // Simulated QR code placeholder
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                      border: Border.all(color: FoodieitTheme.divider),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2, size: 120, color: FoodieitTheme.textPrimary),
                        const SizedBox(height: 12),
                        SelectableText(
                          'otpauth://totp/Foodieit:${u.email}?secret=$secret&issuer=Foodieit',
                          style: TextStyle(fontSize: 11, color: FoodieitTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Secret key (enter manually if you cannot scan):',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    secret!,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: FoodieitTheme.primary, letterSpacing: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('2. Save your recovery codes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Each code can be used once if you lose access to your authenticator device.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  ...?recoveryCodes?.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.key, size: 16, color: FoodieitTheme.warning),
                        const SizedBox(width: 8),
                        SelectableText(c, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: codesAcknowledged,
                        onChanged: (v) => setState(() => codesAcknowledged = v ?? false),
                      ),
                      Expanded(child: Text('I have saved these recovery codes in a secure location.',
                          style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: codesAcknowledged ? () {
                      Navigator.pop(context);
                      showFeedback(context, 'MFA enrolled successfully! Use your authenticator app on next login.');
                    } : null,
                    child: const Text('Complete enrolment'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int step;
  final String text;
  const _StepItem(this.step, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(color: FoodieitTheme.primary, shape: BoxShape.circle),
          child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    ),
  );
}

/// MFA management screen — view status, change factor, disable, re-verify.
class MfaManagementScreen extends StatelessWidget {
  const MfaManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final u = store.current!;

    return Scaffold(
      appBar: AppBar(title: const Text('Security & MFA')),
      body: PageBody(
        children: [
          // Status card
          BrandedCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: u.mfa.enrolled ? FoodieitTheme.successBg : FoodieitTheme.warningBg,
                        borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                      ),
                      child: Icon(
                        u.mfa.enrolled ? Icons.verified_user : Icons.warning,
                        size: 28,
                        color: u.mfa.enrolled ? FoodieitTheme.success : FoodieitTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MFA Status', style: Theme.of(context).textTheme.titleMedium),
                          Text(u.mfa.enrolled ? 'Enabled (${u.mfa.factorType.toUpperCase()})' : 'Not enabled',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: u.mfa.enrolled ? FoodieitTheme.success : FoodieitTheme.warning,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                if (u.mfa.enrolled && u.mfa.enrolledAt != null) ...[
                  const SizedBox(height: 12),
                  InfoRow(icon: Icons.calendar_today, label: 'Enrolled on', value: u.mfa.enrolledAt!.toLocal().toString().substring(0, 16)),
                ],
                if (u.mfa.enrolled && u.mfa.lastVerifiedAt != null) ...[
                  InfoRow(icon: Icons.access_time, label: 'Last verified', value: u.mfa.lastVerifiedAt!.toLocal().toString().substring(0, 16)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!u.mfa.enrolled) ...[
            BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enable MFA', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Protect your account with two-factor authentication. '
                      'You will need an authenticator app like Google Authenticator or Authy.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MfaEnrolScreen())),
                    icon: const Icon(Icons.lock_person),
                    label: const Text('Enable MFA'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // MFA is enabled — management options
            BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current factor: ${u.mfa.factorType.toUpperCase()}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Recovery codes remaining: ${u.mfa.recoveryCodes.length}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (u.mfa.recoveryCodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: FoodieitTheme.dangerBg, borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                        child: Row(
                          children: [
                            Icon(Icons.warning, size: 16, color: FoodieitTheme.danger),
                            const SizedBox(width: 8),
                            Expanded(child: Text('No recovery codes left. Please re-enrol to get new ones.',
                                style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Change factor requires recent auth
                  if (u.mfa.requiresRecentAuth())
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: FoodieitTheme.warningBg, borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: FoodieitTheme.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Recent authentication required to change MFA settings. Please sign out and back in.',
                              style: TextStyle(fontSize: 12, color: FoodieitTheme.warning, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    )
                  else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            // Show factor change options
                            editForm(
                              context,
                              title: 'Change MFA factor',
                              fields: [
                                FieldSpec('factor', 'Factor type (totp, sms, email)', value: u.mfa.factorType),
                              ],
                              save: (d) => store.changeMfaFactor(d['factor']!),
                            );
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Change factor'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (await confirmAction(context, 'Disable MFA? Your account will be less secure.')) {
                              store.disableMfa();
                              if (context.mounted) showFeedback(context, 'MFA disabled');
                            }
                          },
                          icon: Icon(Icons.lock_open, color: FoodieitTheme.danger),
                          label: Text('Disable MFA', style: TextStyle(color: FoodieitTheme.danger)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
