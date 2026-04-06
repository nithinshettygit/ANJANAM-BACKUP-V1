import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:ecommerce_app/features/auth/data/auth_error_mapper.dart';
import 'package:ecommerce_app/features/auth/state/auth_actions_controller.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/auth/utils/auth_input_validators.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int _kMaxEmailFailures = 5;
const Duration _kEmailLockDuration = Duration(minutes: 15);

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

  int _emailFailCount = 0;
  DateTime? _emailLockedUntil;

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

  bool _isLocked(DateTime? until) => until != null && DateTime.now().isBefore(until);

  Future<void> _finishSuccessfulLogin() async {
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
        final role = profile?['role']?.toString().toLowerCase().trim();
        isAdmin = role == 'admin' || role == 'super_admin';
      } catch (_) {
        isAdmin = false;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login successful')),
    );
    _emailFailCount = 0;
    _emailLockedUntil = null;
    if (isAdmin) {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else {
      goToStorefrontAfterCustomerAuth(ref, context);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    if (_isLocked(_emailLockedUntil)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many failed attempts. Try again after '
            '${_emailLockedUntil!.difference(DateTime.now()).inMinutes + 1} min.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    Object? failure;

    try {
      await ref.read(authActionsProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      await _finishSuccessfulLogin();
    } catch (e) {
      failure = e;
      _emailFailCount++;
      if (_emailFailCount >= _kMaxEmailFailures) {
        _emailLockedUntil = DateTime.now().add(_kEmailLockDuration);
        _emailFailCount = 0;
      }
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
    final emailErr = validateEmailField(email);
    if (emailErr != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emailErr)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authActionsProvider.notifier).sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for this email, we sent reset instructions. '
            'Links expire after a short time for security.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final ex = resolvePresentableAuthError(e, isSignUp: false);
      await presentAuthIssue(
        context,
        flow: AuthIssueFlow.passwordReset,
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
      final role = profile?['role']?.toString().toLowerCase().trim();
      isAdmin = role == 'admin' || role == 'super_admin';
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
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: validateEmailField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
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
