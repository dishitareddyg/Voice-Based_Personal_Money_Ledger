import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../providers/auth_provider.dart';
import '../../../router/routes.dart';
import 'widgets/auth_scaffold.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;
  String _passwordText = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).register(
            fullName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (mounted) context.go(Routes.dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'Account creation failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your ledger',
      subtitle:
          'Your records stay on your Raspberry Pi and are isolated from other users.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already registered?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          TextButton(
            onPressed: _loading ? null : () => context.go(Routes.login),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                InfoBanner(
                  message: _error!,
                  title: 'Could not create account',
                  icon: Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
              ],
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Ananya Sharma',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: Validators.name,
                enabled: !_loading,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _emailController,
                label: 'Email address',
                hint: 'you@example.com',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                enabled: !_loading,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'At least 8 characters',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                onChanged: (value) => setState(() => _passwordText = value),
                enabled: !_loading,
              ),
              const SizedBox(height: 8),
              _PasswordStrength(password: _passwordText),
              const SizedBox(height: 12),
              AppTextField(
                controller: _confirmController,
                label: 'Confirm password',
                prefixIcon: Icons.verified_user_outlined,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => Validators.confirmPassword(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _loading ? null : _submit(),
                enabled: !_loading,
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Create account',
                icon: Icons.person_add_alt_1_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 14),
              Text(
                'By creating an account you agree to keep your ledger password private. '
                'Financial balances are calculated and validated by the server.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) || password.length >= 12) {
      score++;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = _score;
    final color = score <= 1
        ? scheme.error
        : score == 2
            ? const Color(0xFFC57921)
            : score == 3
                ? const Color(0xFF2D6FBE)
                : const Color(0xFF17815E);

    return Row(
      children: [
        ...List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 3 ? 10 : 5),
              decoration: BoxDecoration(
                color: index < score
                    ? color
                    : scheme.outlineVariant.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
        SizedBox(
          width: 62,
          child: Text(
            score == 0
                ? ''
                : score <= 1
                    ? 'Weak'
                    : score == 2
                        ? 'Fair'
                        : score == 3
                            ? 'Good'
                            : 'Strong',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
