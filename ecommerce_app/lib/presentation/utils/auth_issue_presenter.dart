import 'package:ecommerce_app/core/auth/blocked_account_gate.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecommerce_app/l10n/app_localizations.dart';

/// Where the auth error was surfaced (affects titles and secondary actions).
enum AuthIssueFlow { login, signup, signOut, passwordReset }

/// Guest tried to use the server cart (e.g. add to cart). Matches messaging from
/// [SupabaseCartService] when there is no session.
Future<void> presentSignInToManageCartDialog(BuildContext context) async {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        icon: Icon(
          Icons.shopping_cart_outlined,
          color: scheme.primary,
          size: 32,
        ),
        title: Text(AppLocalizations.of(context).signInToAddToCart),
        content: Text(
          AppLocalizations.of(context).signInRequiredToManageCart,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context).close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/login');
            },
            child: Text(AppLocalizations.of(context).signIn),
          ),
        ],
      );
    },
  );
}

/// Presents authentication failures in a clear dialog with retry and optional navigation.
Future<void> presentAuthIssue(
  BuildContext context, {
  required AuthException error,
  required AuthIssueFlow flow,
  required VoidCallback onRetry,
  /// When email send is capped, prefer this over leaving the page (e.g. [LoginPage] / [SignupPage]).
  VoidCallback? onContinueWithGoogle,
}) async {
  if (error.kind == AuthFailureKind.accountSuspended) {
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(blockedAccountGateProvider).presentRestricted(
          detection: null,
          message: error.message,
        );
    return;
  }

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  final title = _titleFor(error.kind, flow);
  final secondary = _secondaryFor(context, error.kind, flow);
  final googleAction = _googleActionFor(
    context,
    kind: error.kind,
    flow: flow,
    onContinueWithGoogle: onContinueWithGoogle,
  );

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        icon: Icon(
          error.kind == AuthFailureKind.emailSendLimited
              ? Icons.mark_email_unread_outlined
              : Icons.gpp_maybe_outlined,
          color: scheme.error,
          size: 32,
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            error.message,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          if (secondary != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                secondary.onPressed();
              },
              child: Text(secondary.label),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (_showRetry(error.kind, flow) && googleAction == null)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: Text(_retryLabel(error.kind, flow)),
            ),
          if (googleAction != null)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                googleAction();
              },
              child: const Text('Continue with Google'),
            ),
        ],
      );
    },
  );
}

bool _showRetry(AuthFailureKind kind, AuthIssueFlow flow) {
  if (kind == AuthFailureKind.accountSuspended) return false;
  // Immediate retry just hits the same mail cap again.
  if (kind == AuthFailureKind.emailSendLimited) return false;
  if (flow == AuthIssueFlow.signOut) return true;
  if (flow == AuthIssueFlow.passwordReset) return true;
  if (kind == AuthFailureKind.emailNotConfirmed) return true;
  if (kind == AuthFailureKind.accountExists && flow == AuthIssueFlow.signup) {
    return false;
  }
  return true;
}

String _retryLabel(AuthFailureKind kind, AuthIssueFlow flow) {
  if (flow == AuthIssueFlow.signOut) return 'Try again';
  if (flow == AuthIssueFlow.passwordReset) return 'Try again';
  if (kind == AuthFailureKind.emailNotConfirmed) return 'Try again';
  return 'Try again';
}

String _titleFor(AuthFailureKind kind, AuthIssueFlow flow) {
  switch (flow) {
    case AuthIssueFlow.signOut:
      return 'Unable to sign out';
    case AuthIssueFlow.signup:
      switch (kind) {
        case AuthFailureKind.accountExists:
          return 'Account already exists';
        case AuthFailureKind.accountSuspended:
          return 'Account restricted';
        case AuthFailureKind.weakPassword:
          return 'Password requirements';
        case AuthFailureKind.network:
          return 'Connection problem';
        case AuthFailureKind.rateLimited:
          return 'Please try later';
        case AuthFailureKind.emailSendLimited:
          return 'Confirmation email delayed';
        default:
          return 'Registration could not be completed';
      }
    case AuthIssueFlow.login:
      switch (kind) {
        case AuthFailureKind.invalidCredentials:
          return 'Sign-in unsuccessful';
        case AuthFailureKind.emailNotConfirmed:
          return 'Email confirmation required';
        case AuthFailureKind.network:
          return 'Connection problem';
        case AuthFailureKind.accountSuspended:
          return 'Account restricted';
        case AuthFailureKind.sessionExpired:
          return 'Session ended';
        case AuthFailureKind.rateLimited:
          return 'Please wait';
        case AuthFailureKind.emailSendLimited:
          return 'Email delayed';
        default:
          return 'Sign-in could not be completed';
      }
    case AuthIssueFlow.passwordReset:
      switch (kind) {
        case AuthFailureKind.accountSuspended:
          return 'Account restricted';
        case AuthFailureKind.weakPassword:
          return 'Password requirements';
        case AuthFailureKind.sessionExpired:
          return 'Session ended';
        case AuthFailureKind.network:
          return 'Connection problem';
        case AuthFailureKind.rateLimited:
          return 'Please wait';
        case AuthFailureKind.emailSendLimited:
          return 'Email delayed';
        default:
          return 'Could not update password';
      }
  }
}

class _Secondary {
  final String label;
  final VoidCallback onPressed;

  const _Secondary({required this.label, required this.onPressed});
}

/// Opens Google via page callback, or lands on the auth chooser (Google CTA).
VoidCallback? _googleActionFor(
  BuildContext context, {
  required AuthFailureKind kind,
  required AuthIssueFlow flow,
  VoidCallback? onContinueWithGoogle,
}) {
  if (kind != AuthFailureKind.emailSendLimited) return null;
  if (flow != AuthIssueFlow.signup &&
      flow != AuthIssueFlow.login &&
      flow != AuthIssueFlow.passwordReset) {
    return null;
  }
  if (onContinueWithGoogle != null) return onContinueWithGoogle;
  return () => Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
}

_Secondary? _secondaryFor(
  BuildContext context,
  AuthFailureKind kind,
  AuthIssueFlow flow,
) {
  switch (flow) {
    case AuthIssueFlow.login:
      if (kind == AuthFailureKind.invalidCredentials) {
        return _Secondary(
          label: 'Create account',
          onPressed: () => Navigator.of(context).pushNamed('/signup'),
        );
      }
      if (kind == AuthFailureKind.accountSuspended) {
        return null;
      }
      if (kind == AuthFailureKind.emailSendLimited) {
        return _Secondary(
          label: 'Back to options',
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              ),
        );
      }
      return null;
    case AuthIssueFlow.signup:
      if (kind == AuthFailureKind.accountExists) {
        return _Secondary(
          label: 'Go to sign in',
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        );
      }
      if (kind == AuthFailureKind.emailSendLimited) {
        return _Secondary(
          label: 'Back to sign in',
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        );
      }
      if (kind == AuthFailureKind.weakPassword ||
          kind == AuthFailureKind.network ||
          kind == AuthFailureKind.rateLimited ||
          kind == AuthFailureKind.unknown) {
        return _Secondary(
          label: 'Already registered? Sign in',
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        );
      }
      return null;
    case AuthIssueFlow.signOut:
      return null;
    case AuthIssueFlow.passwordReset:
      return _Secondary(
        label: 'Back to sign in',
        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
      );
  }
}
