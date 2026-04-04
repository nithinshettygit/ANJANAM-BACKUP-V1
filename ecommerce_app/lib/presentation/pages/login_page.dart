import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:ecommerce_app/features/auth/data/auth_error_mapper.dart';
import 'package:ecommerce_app/features/auth/state/auth_actions_controller.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _sessionRedirectScheduled = false;
  bool _authListenAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authListenAttached) return;
    _authListenAttached = true;
    ref.listenManual<AsyncValue<AppUser?>>(
      authSessionProvider,
      (previous, next) {
        next.whenData((user) {
          if (user == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _redirectIfAlreadySignedIn();
          });
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    Object? failure;

    try {
      await ref.read(authActionsProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      final client = ref.read(supabaseClientProvider);
      final authUser = client.auth.currentUser;
      var isAdmin = false;
      if (authUser != null) {
        try {
          final profile = await client
              .from('profiles')
              .select('role')
              .eq('id', authUser.id)
              .maybeSingle();
          isAdmin = profile?['role']?.toString().toLowerCase() == 'admin';
        } catch (_) {
          isAdmin = false;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
      if (isAdmin) {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else {
        goToStorefrontAfterCustomerAuth(ref, context);
      }
    } catch (e) {
      failure = e;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (failure != null && mounted) {
      final ex = resolvePresentableAuthError(failure, isSignUp: false);
      await presentAuthIssue(
        context,
        flow: AuthIssueFlow.login,
        error: ex,
        onRetry: _submit,
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authActionsProvider.notifier).sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final ex = resolvePresentableAuthError(e, isSignUp: false);
      await presentAuthIssue(
        context,
        flow: AuthIssueFlow.login,
        error: ex,
        onRetry: _sendPasswordReset,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _redirectIfAlreadySignedIn() async {
    if (_sessionRedirectScheduled || !mounted) return;
    _sessionRedirectScheduled = true;
    final client = ref.read(supabaseClientProvider);
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      _sessionRedirectScheduled = false;
      return;
    }
    var isAdmin = false;
    try {
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', authUser.id)
          .maybeSingle();
      isAdmin = profile?['role']?.toString().toLowerCase() == 'admin';
    } catch (_) {
      isAdmin = false;
    }
    if (!mounted) return;
    if (isAdmin) {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else {
      goToStorefrontAfterCustomerAuth(ref, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? 'Logging in...' : 'Login'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _sendPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/signup'),
                  child: const Text('Don\'t have an account? Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

