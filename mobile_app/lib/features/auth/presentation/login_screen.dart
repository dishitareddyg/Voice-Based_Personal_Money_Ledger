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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (mounted) context.go(Routes.dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'Sign in failed. Please check your details and try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see your balance, loans and recent activity.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'New here?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          TextButton(
            onPressed: _loading ? null : () => context.go(Routes.register),
            child: const Text('Create an account'),
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
                  title: 'Could not sign in',
                  icon: Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
              ],
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
                hint: 'Your ledger password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (value) => Validators.required(
                  value,
                  label: 'Password',
                ),
                onFieldSubmitted: (_) => _loading ? null : _submit(),
                enabled: !_loading,
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Sign in',
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              InfoBanner(
                icon: Icons.privacy_tip_outlined,
                message:
                    'Speak naturally. Audio is transcribed on this phone and is never uploaded.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
