import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after the user opens the **email confirmation** link (not password reset).
/// Replaces sending them straight to [MainShell] so the flow is explicit.
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
    }
  }

  @override
  void initState() {
    super.initState();
    _evaluateSession(Supabase.instance.client.auth.currentSession);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _evaluateSession(data.session);
    });
    Future<void>.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (!_confirmed) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _continueToApp() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
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
                    'Your sign-in link was processed. You can continue to the app.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _continueToApp,
                    child: const Text('Continue to app'),
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
                  'or was already used. Try signing in, or request a new confirmation email from sign up.',
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
                'You are signed in. Continue to the app, or sign out from your account tab if you use a shared device.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _continueToApp,
                child: const Text('Continue to app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
