import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final identifier = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (!form.currentState!.validate()) return;
    final store = AppScope.of(context);
    setState(() => loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final needsMfa = store.login(identifier.text, password.text);
        // If MFA is needed, the main.dart Builder will switch to MfaVerifyScreen
        // If not, it will switch to HomeShell
        if (!needsMfa && mounted) {
          setState(() => loading = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => loading = false);
          showFeedback(context, e is StateError ? e.message.toString() : 'Invalid login details.', isError: true);
        }
      }
    });
  }

  void register(Role role) {
    final store = AppScope.of(context);

    if (role == Role.rider) {
      // Rider registration uses the full application form
      Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => const _RiderRegistrationScreen(),
      ));
      return;
    }

    editForm(
      context,
      title: 'Create ${role.name} account',
      fields: const [
        FieldSpec('name', 'Full name'),
        FieldSpec('email', 'Email', keyboard: TextInputType.emailAddress),
        FieldSpec('phone', 'Phone', keyboard: TextInputType.phone),
        FieldSpec('address', 'Address', optional: true, maxLines: 2),
        FieldSpec('password', 'Password (8-72 characters)', secret: true),
      ],
      save: (d) => store.register(
          role: role,
          name: d['name']!,
          email: d['email']!,
          password: d['password']!,
          phone: d['phone']!,
          address: d['address']!),
      saveLabel: 'Create account',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodieitTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: FoodieitTheme.primary,
                        borderRadius: BorderRadius.circular(FoodieitTheme.radiusXl),
                        boxShadow: FoodieitTheme.shadowMd,
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.restaurant_menu, size: 48, color: Colors.white),
                          SizedBox(height: 8),
                          Text('Foodieit',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5)),
                          SizedBox(height: 4),
                          Text('Good food. Your doorstep.',
                              style: TextStyle(fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    BrandedCard(
                      padding: const EdgeInsets.all(24),
                      shadow: FoodieitTheme.shadowMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Welcome back',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text('Sign in to order your favourite meals',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: identifier,
                            decoration: const InputDecoration(
                              labelText: 'Email or admin username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Enter your login' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: password,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => obscure = !obscure),
                                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Enter your password' : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: loading ? null : _signIn,
                            child: loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Sign in'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text('New to Foodieit?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => register(Role.customer),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Create customer account'),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => register(Role.rider),
                      icon: const Icon(Icons.delivery_dining_outlined),
                      label: const Text('Register as a rider'),
                    ),

                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
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
                              Icon(Icons.info_outline, size: 16, color: FoodieitTheme.warning),
                              const SizedBox(width: 6),
                              Text('SIMULATOR DEMO - local data resets on restart',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: FoodieitTheme.warning)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const SelectableText(
                            'Admin: admin 123 / admin@example\nCustomer: customer@example.com / Customer123!\nRider: rider@example.com / Rider123!',
                            style: TextStyle(fontSize: 12, color: FoodieitTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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

/// Rider registration screen with full application form including vehicle details.
class _RiderRegistrationScreen extends StatefulWidget {
  const _RiderRegistrationScreen();
  @override
  State<_RiderRegistrationScreen> createState() => _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState extends State<_RiderRegistrationScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final regNumber = TextEditingController();
  final vehicleMake = TextEditingController();
  final vehicleModel = TextEditingController();
  final vehicleColor = TextEditingController();
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    name.dispose(); email.dispose(); phone.dispose(); password.dispose();
    regNumber.dispose(); vehicleMake.dispose(); vehicleModel.dispose(); vehicleColor.dispose();
    super.dispose();
  }

  void _submit() {
    if (!form.currentState!.validate()) return;
    final store = AppScope.of(context);
    setState(() => loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        store.registerRiderApplication(
          name: name.text,
          email: email.text,
          password: password.text,
          phone: phone.text,
          regNumber: regNumber.text,
          vehicleMake: vehicleMake.text,
          vehicleModel: vehicleModel.text,
          vehicleColor: vehicleColor.text,
        );
        if (mounted) {
          showFeedback(context, 'Application submitted! Upload your documents next.');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => loading = false);
          showFeedback(context, e is StateError ? e.message.toString() : 'Registration failed.', isError: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Application')),
      body: PageBody(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FoodieitTheme.infoBg,
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: FoodieitTheme.info),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'New rider accounts start with Pending Approval status. '
                  'You can log in while pending to upload documents and check your status. '
                  'Only approved riders with valid documents can accept delivery jobs.',
                  style: TextStyle(fontSize: 12, color: FoodieitTheme.info, fontWeight: FontWeight.w600),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Form(
            key: form,
            child: BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Personal Information', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().length < 7 ? 'Valid phone required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password (8-72 characters)',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8 ? 'Minimum 8 characters' : null,
                  ),
                  const SizedBox(height: 24),

                  Text('Vehicle Information', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: regNumber,
                    decoration: const InputDecoration(labelText: 'Motorcycle registration number', prefixIcon: Icon(Icons.motorcycle)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(
                        controller: vehicleMake,
                        decoration: const InputDecoration(labelText: 'Make'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: vehicleModel,
                        decoration: const InputDecoration(labelText: 'Model'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: vehicleColor,
                    decoration: const InputDecoration(labelText: 'Color'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  Text('Documents', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('After registration, you will be able to upload:',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  for (final type in DocumentType.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(type.icon, size: 16, color: FoodieitTheme.primary),
                          const SizedBox(width: 8),
                          Text(type.label, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit application'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
