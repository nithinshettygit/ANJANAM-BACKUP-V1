import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:ecommerce_app/features/auth/data/auth_error_mapper.dart';
import 'package:ecommerce_app/features/auth/data/services/firebase_google_auth_service.dart';
import 'package:ecommerce_app/features/auth/state/auth_actions_controller.dart';
import 'package:ecommerce_app/features/auth/state/auth_local_session_store.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/auth/utils/auth_input_validators.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/core/network/network_request_guard.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecommerce_app/firebase_options.dart';

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
  bool _isGoogleSubmitting = false;
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
    if (authUser != null) {
      await ref.read(authLocalSessionStoreProvider).save(
            userId: authUser.id,
            loginType: LoginType.email,
          );
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
        onContinueWithGoogle: _submitGoogle,
      );
    }
  }

  Future<void> _submitGoogle() async {
    if (_isSubmitting || _isGoogleSubmitting) return;
    if (!await NetworkRequestGuard.hasConnection()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(NetworkRequestGuard.offlineMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _submitGoogle),
        ),
      );
      return;
    }
    if (kIsWeb && Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {}
    }
    if (kIsWeb && Firebase.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google login is unavailable right now. Please refresh and try again.'),
        ),
      );
      return;
    }
    setState(() => _isGoogleSubmitting = true);
    try {
      final auth = ref.read(firebaseGoogleAuthServiceProvider);
      final firebaseCred = await auth.signInWithGoogle();
      final firebaseUser = firebaseCred.user;
      if (firebaseUser == null) {
        throw Exception('Google sign-in did not return a user.');
      }
      final appUser = await auth.signInToSupabaseFromGoogleUser(
        firebaseCredential: firebaseCred,
      );
      await ref.read(authLocalSessionStoreProvider).save(
            userId: appUser.id,
            loginType: LoginType.google,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
      goToStorefrontAfterCustomerAuth(ref, context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final code = e.code.toLowerCase().trim();
      final isCancel = code == 'google-sign-in-cancelled' ||
          code == 'popup-closed-by-user' ||
          code == 'cancelled-popup-request';
      final isPopupIssue = code == 'popup-blocked' || code == 'operation-not-allowed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCancel
                ? 'Google sign-in cancelled.'
                : isPopupIssue
                    ? 'Google popup blocked or not enabled in Firebase Auth (${e.code}).'
                    : _networkAwareMessage(e),
          ),
          action: isCancel ? null : SnackBarAction(label: 'Retry', onPressed: _submitGoogle),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_networkAwareMessage(e)),
          action: SnackBarAction(label: 'Retry', onPressed: _submitGoogle),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  String _networkAwareMessage(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('timed out') || lower.contains('timeoutexception')) {
      return NetworkRequestGuard.timeoutMessage;
    }
    if (lower.contains("you're offline")) return NetworkRequestGuard.offlineMessage;
    if (NetworkRequestGuard.isTransientNetworkError(error)) {
      return NetworkRequestGuard.noInternetMessage;
    }
    return 'Unable to continue with Google.';
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
        onContinueWithGoogle: _submitGoogle,
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
      appBar: AppBar(
        title: const Text('Login'),
        // Web/iPad only: always show back (stack may be empty after auth redirect).
        leading: kIsWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushReplacementNamed('/');
                  }
                },
              )
            : null,
      ),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_isSubmitting || _isGoogleSubmitting) ? null : _submitGoogle,
                    icon: _isGoogleSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded),
                    label: Text(
                      _isGoogleSubmitting ? 'Connecting to Google...' : 'Continue with Google',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
