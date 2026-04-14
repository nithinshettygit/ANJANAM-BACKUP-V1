import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/data/auth_error_mapper.dart';
import 'package:ecommerce_app/features/auth/data/services/firebase_google_auth_service.dart';
import 'package:ecommerce_app/features/auth/state/auth_actions_controller.dart';
import 'package:ecommerce_app/features/auth/state/auth_local_session_store.dart';
import 'package:ecommerce_app/features/auth/utils/auth_input_validators.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecommerce_app/firebase_options.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    Object? failure;

    try {
      await ref.read(authActionsProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            userName: _userNameController.text.trim(),
          );
      if (!mounted) return;
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your account has been created. If email confirmation is required, '
              'please check your inbox before signing in.',
            ),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login/email');
        return;
      }
      await ref.read(authLocalSessionStoreProvider).save(
            userId: session.user.id,
            loginType: LoginType.email,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration completed successfully.')),
      );
      goToStorefrontAfterCustomerAuth(ref, context);
    } catch (e) {
      failure = e;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (failure != null && mounted) {
      final ex = resolvePresentableAuthError(failure, isSignUp: true);
      await presentAuthIssue(
        context,
        flow: AuthIssueFlow.signup,
        error: ex,
        onRetry: _submit,
      );
    }
  }

  Future<void> _submitGoogle() async {
    if (_isSubmitting || _isGoogleSubmitting) return;
    if (kIsWeb && Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {}
    }
    if (kIsWeb && Firebase.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-up is unavailable right now. Please refresh and try again.'),
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
        const SnackBar(content: Text('Registration completed successfully.')),
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
                : (e.message?.trim().isNotEmpty == true
                    ? '${e.message!.trim()} (${e.code})'
                    : 'Unable to continue with Google.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _userNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Username is required';
                    if (t.length < 2) return 'Username must be at least 2 characters';
                    if (t.length > 80) return 'Username is too long';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: validateEmailField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: validatePasswordField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm password is required';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? 'Creating account...' : 'Sign Up'),
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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login/email'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
