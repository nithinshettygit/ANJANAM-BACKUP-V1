import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:ecommerce_app/firebase_options.dart';

import '../../core/supabase/supabase_client_provider.dart';
import '../../features/auth/data/services/firebase_google_auth_service.dart';
import '../../features/auth/state/auth_local_session_store.dart';
import '../utils/main_shell_navigation.dart';
import 'phone_login_page.dart';

class AuthChoicePage extends ConsumerStatefulWidget {
  const AuthChoicePage({super.key});

  @override
  ConsumerState<AuthChoicePage> createState() => _AuthChoicePageState();
}

class _AuthChoicePageState extends ConsumerState<AuthChoicePage> {
  bool _resuming = false;
  bool _googleLoading = false;

  Future<bool> _ensureFirebaseWebReady() async {
    if (!kIsWeb) return true;
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeIfSessionExists();
    });
  }

  Future<void> _resumeIfSessionExists() async {
    setState(() => _resuming = true);
    final local = await ref.read(authLocalSessionStoreProvider).load();
    if (!mounted) return;
    final current = ref.read(supabaseClientProvider).auth.currentUser;
    if (local != null && current != null && current.id == local.userId) {
      goToStorefrontAfterCustomerAuth(ref, context);
      return;
    }
    if (local?.loginType == LoginType.phone) {
      try {
        final appUser = await ref.read(firebasePhoneAuthServiceProvider).resumePhoneSessionIfAvailable();
        if (!mounted || appUser == null) return;
        await ref.read(authLocalSessionStoreProvider).save(
              userId: appUser.id,
              loginType: LoginType.phone,
            );
        if (!mounted) return;
        goToStorefrontAfterCustomerAuth(ref, context);
        return;
      } catch (_) {
        // Silent fallback to chooser.
      }
    }
    if (mounted) setState(() => _resuming = false);
  }

  Future<void> _continueWithGoogle() async {
    if (_resuming || _googleLoading) return;
    final firebaseReady = await _ensureFirebaseWebReady();
    if (!firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google/Phone login is unavailable right now. Please refresh and try again.',
          ),
        ),
      );
      return;
    }
    setState(() => _googleLoading = true);
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
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Choose how to continue',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 20),
              if (_resuming)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              FilledButton.icon(
                onPressed: _resuming ? null : () => Navigator.of(context).pushNamed('/login/phone'),
                icon: const Icon(Icons.phone_android_outlined),
                label: const Text('Continue with Mobile Number'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: (_resuming || _googleLoading) ? null : _continueWithGoogle,
                icon: _googleLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata_rounded),
                label: Text(_googleLoading ? 'Connecting to Google...' : 'Continue with Google'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _resuming ? null : () => Navigator.of(context).pushNamed('/login/email'),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Continue with Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
