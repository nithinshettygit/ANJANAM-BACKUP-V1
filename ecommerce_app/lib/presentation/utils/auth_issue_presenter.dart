import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:flutter/material.dart';

/// Where the auth error was surfaced (affects titles and secondary actions).
enum AuthIssueFlow { login, signup, signOut, passwordReset }

/// Presents authentication failures in a clear dialog with retry and optional navigation.
Future<void> presentAuthIssue(
  BuildContext context, {
  required AuthException error,
  required AuthIssueFlow flow,
  required VoidCallback onRetry,
}) async {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  final title = _titleFor(error.kind, flow);
  final secondary = _secondaryFor(context, error.kind, flow);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        icon: Icon(Icons.gpp_maybe_outlined, color: scheme.error, size: 32),
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
          if (_showRetry(error.kind, flow))
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: Text(_retryLabel(error.kind, flow)),
            ),
        ],
      );
    },
  );
}

bool _showRetry(AuthFailureKind kind, AuthIssueFlow flow) {
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
        case AuthFailureKind.weakPassword:
          return 'Password requirements';
        case AuthFailureKind.network:
          return 'Connection problem';
        case AuthFailureKind.rateLimited:
          return 'Service limit reached';
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
        case AuthFailureKind.sessionExpired:
          return 'Session ended';
        case AuthFailureKind.rateLimited:
          return 'Please wait';
        default:
          return 'Sign-in could not be completed';
      }
    case AuthIssueFlow.passwordReset:
      switch (kind) {
        case AuthFailureKind.weakPassword:
          return 'Password requirements';
        case AuthFailureKind.sessionExpired:
          return 'Session ended';
        case AuthFailureKind.network:
          return 'Connection problem';
        case AuthFailureKind.rateLimited:
          return 'Please wait';
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
      return null;
    case AuthIssueFlow.signup:
      if (kind == AuthFailureKind.accountExists) {
        return _Secondary(
          label: 'Go to sign in',
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
