import 'dart:async';

import 'package:ecommerce_app/core/auth/auth_email_link_navigation.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after the user opens the **email confirmation** link (not password reset).
/// Supabase exchanges the PKCE `code` from the URL (via [Supabase.initialize] deep link observer).
class EmailConfirmationCallbackPage extends ConsumerStatefulWidget {
  const EmailConfirmationCallbackPage({super.key});

  @override
  ConsumerState<EmailConfirmationCallbackPage> createState() =>
      _EmailConfirmationCallbackPageState();
}

class _EmailConfirmationCallbackPageState extends ConsumerState<EmailConfirmationCallbackPage> {
  StreamSubscription<AuthState>? _authSub;
  bool _confirmed = false;
  bool _timedOut = false;
  String? _linkError;
  Timer? _autoContinueTimer;

  static const _timeout = Duration(seconds: 30);
  static const _autoRedirectDelay = Duration(milliseconds: 1600);

  static bool _emailIsVerified(User user) {
    final email = user.email?.trim() ?? '';
    if (email.isEmpty) return true;
    final at = user.emailConfirmedAt?.trim() ?? '';
    return at.isNotEmpty;
  }

  void _evaluateSession(Session? session) {
    final u = session?.user;
    if (u != null && _emailIsVerified(u) && mounted) {
      setState(() => _confirmed = true);
      _scheduleAutoContinue();
    }
  }

  void _scheduleAutoContinue() {
    _autoContinueTimer?.cancel();
    _autoContinueTimer = Timer(_autoRedirectDelay, () {
      if (!mounted || !_confirmed) return;
      goToStorefrontAfterCustomerAuth(ref, context);
    });
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _linkError = parseAuthCallbackErrorFromUri(Uri.base);
    }
    _evaluateSession(Supabase.instance.client.auth.currentSession);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _evaluateSession(data.session);
    });
    Future<void>.delayed(_timeout, () {
      if (!mounted) return;
      if (!_confirmed) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _continueToStorefront() {
    _autoContinueTimer?.cancel();
    goToStorefrontAfterCustomerAuth(ref, context);
  }

  @override
  Widget build(BuildContext context) {
    if (_linkError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Email confirmation')),
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
                  'This link may have expired, already been used, or is invalid. '
                  'Request a new confirmation email or sign in.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Go to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_timedOut && !_confirmed) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Email confirmation')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your sign-in link was processed. Continue to the store.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _continueToStorefront,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Email confirmation')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'We could not confirm your email from this link. It may have expired, '
                  'or was already used. Try signing in, or request a new confirmation email.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Go to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_confirmed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirming email')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying your email…'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Email verified')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your email address has been verified.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'You are signed in. Taking you to your account…',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _continueToStorefront,
                child: const Text('Continue now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
