import 'dart:async';

import 'package:ecommerce_app/core/auth/auth_email_link_navigation.dart';
import 'package:ecommerce_app/features/auth/data/auth_error_mapper.dart';
import 'package:ecommerce_app/features/auth/state/auth_actions_controller.dart';
import 'package:ecommerce_app/features/auth/utils/auth_input_validators.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after the user opens the password-reset link from email (web or APK).
class UpdatePasswordPage extends ConsumerStatefulWidget {
  const UpdatePasswordPage({super.key});

  @override
  ConsumerState<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends ConsumerState<UpdatePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  StreamSubscription<AuthState>? _authSub;
  bool _sessionReady = false;
  bool _timedOut = false;
  bool _isSubmitting = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _linkError = parseAuthCallbackErrorFromUri(Uri.base);
    }
    if (Supabase.instance.client.auth.currentSession != null) {
      _sessionReady = true;
    } else {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null && mounted) {
          setState(() => _sessionReady = true);
        }
      });
      Future<void>.delayed(const Duration(seconds: 25), () {
        if (!mounted) return;
        if (!_sessionReady) setState(() => _timedOut = true);
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    Object? failure;
    try {
      await ref.read(authActionsProvider.notifier).updatePasswordFromRecoverySession(
            newPassword: _passwordController.text,
          );
      await ref.read(authActionsProvider.notifier).signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Sign in with your new password.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      failure = e;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (failure != null && mounted) {
      final ex = resolvePresentableAuthError(failure, isSignUp: false);
      await presentAuthIssue(
        context,
        flow: AuthIssueFlow.passwordReset,
        error: ex,
        onRetry: _submit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_linkError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _linkError!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Reset links expire after a short time and can only be used once. '
                  'Request a new email from the sign-in page.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_timedOut && !_sessionReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'This reset link is invalid or has expired. Request a new one from the sign-in page.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_sessionReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying your reset link…'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter a new password for your account.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: validatePasswordField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Saving…' : 'Update password'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
