import 'package:ecommerce_app/core/auth/blocked_account_codes.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/network/network_request_guard.dart';
import 'package:gotrue/gotrue.dart' as gt;

/// Converts API and wrapper errors into [AuthException] with stable [AuthFailureKind].
AuthException resolvePresentableAuthError(
  Object error, {
  required bool isSignUp,
}) {
  if (error is AuthException) return error;

  if (error is RepositoryException) {
    return _fromPlainText(error.message, isSignUp: isSignUp);
  }

  return _fromGotrue(error, isSignUp: isSignUp) ??
      _fromPlainText(error.toString(), isSignUp: isSignUp);
}

AuthException _fromPlainText(String raw, {required bool isSignUp}) {
  final lower = raw.toLowerCase();
  if (isSignUp) {
    if (lower.contains('profiles_role_check') ||
        (lower.contains('relation "profiles"') &&
            lower.contains('violates check constraint') &&
            lower.contains('role'))) {
      return const AuthException(
        'Account setup is temporarily unavailable due to server configuration. '
        'Please contact support or try again shortly.',
        kind: AuthFailureKind.unknown,
      );
    }
    if (lower.contains('already registered') ||
        lower.contains('user already registered') ||
        lower.contains('already been registered') ||
        lower.contains('email address is already') ||
        lower.contains('already exists') ||
        lower.contains('user_already_exists') ||
        lower.contains('email_exists') ||
        lower.contains('duplicate key value') && lower.contains('email')) {
      return AuthException(
        'This email is already registered. '
        'Please sign in with this email, or use Forgot password if needed.',
        kind: AuthFailureKind.accountExists,
      );
    }
    if (lower.contains('password') &&
        (lower.contains('weak') || lower.contains('least') || lower.contains('short'))) {
      return AuthException(
        'The password you chose does not satisfy our security requirements. '
        'Please use a longer password or include a mix of letters, numbers, and symbols.',
        kind: AuthFailureKind.weakPassword,
      );
    }
  } else {
    if (lower.contains('suspended') ||
        lower.contains('blocked') ||
        lower.contains('account is blocked') ||
        lower.contains('account has been suspended')) {
      return const AuthException(
        BlockedAccountCopy.screenMessage,
        kind: AuthFailureKind.accountSuspended,
      );
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid grant')) {
      return AuthException(
        'We could not verify your email address and password. '
        'Please check that your details are correct and try again. '
        'If you do not yet have an account, you may create one using the option below.',
        kind: AuthFailureKind.invalidCredentials,
      );
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return AuthException(
        'Your email address has not been confirmed. '
        'Please open the confirmation message we sent you and follow the link before signing in.',
        kind: AuthFailureKind.emailNotConfirmed,
      );
    }
  }
  if (lower.contains('timed out') || lower.contains('timeoutexception')) {
    return const AuthException(
      NetworkRequestGuard.timeoutMessage,
      kind: AuthFailureKind.network,
    );
  }
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains("you're offline")) {
    return const AuthException(
      NetworkRequestGuard.noInternetMessage,
      kind: AuthFailureKind.network,
    );
  }
  if (_isSupabaseEmailOrAuthQuota(lower)) {
    return _emailQuotaMessage();
  }
  if (lower.contains('too many requests') || lower.contains('rate limit')) {
    return AuthException(
      'Too many attempts were made in a short period. Please wait a moment and try again.',
      kind: AuthFailureKind.rateLimited,
    );
  }
  if (isSignUp &&
      (lower.contains('signups not allowed') ||
          lower.contains('signup_disabled') ||
          lower.contains('sign up is disabled'))) {
    return const AuthException(
      'New account registration is currently disabled for this application. '
      'Please contact support if you believe this is an error.',
      kind: AuthFailureKind.unknown,
    );
  }
  final trimmed = raw.trim();
  if (trimmed.length > 220) {
    return const AuthException(
      'An unexpected error occurred while contacting the authentication service. Please try again.',
      kind: AuthFailureKind.unknown,
    );
  }
  return AuthException(trimmed, kind: AuthFailureKind.unknown);
}

AuthException? _fromGotrue(Object error, {required bool isSignUp}) {
  if (error is gt.AuthWeakPasswordException) {
    final reasons = error.reasons;
    final detail = reasons.isEmpty
        ? ''
        : ' Details: ${reasons.join(' ')}';
    return AuthException(
      'Your password does not meet the required security standard.$detail',
      kind: AuthFailureKind.weakPassword,
    );
  }

  if (error is gt.AuthSessionMissingException) {
    return const AuthException(
      'Your session is no longer active. Please sign in again to continue.',
      kind: AuthFailureKind.sessionExpired,
    );
  }

  if (error is gt.AuthRetryableFetchException) {
    return const AuthException(
      'We could not reach the authentication service. Please verify your connection and try again.',
      kind: AuthFailureKind.network,
    );
  }

  if (error is gt.AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();

    if (isSignUp) {
      if (code == 'user_already_exists' ||
          code.contains('already_registered') ||
          code.contains('email_exists') ||
          msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already')) {
        return AuthException(
          'This email is already registered. '
          'Please sign in with this email, or use Forgot password if needed.',
          kind: AuthFailureKind.accountExists,
        );
      }
    } else {
      if (BlockedAccountCodes.matches(code) ||
          code == 'user_blocked' ||
          code == 'account_blocked' ||
          code == 'admin_blocked' ||
          msg.contains('suspended') ||
          msg.contains('blocked') ||
          msg.contains('disabled')) {
        return const AuthException(
          BlockedAccountCopy.screenMessage,
          kind: AuthFailureKind.accountSuspended,
        );
      }
      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          msg.contains('invalid login credentials')) {
        return AuthException(
          'The email or password entered does not match our records. '
          'Please try again, or create a new account if you have not registered before.',
          kind: AuthFailureKind.invalidCredentials,
        );
      }
      if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
        return const AuthException(
          'You must confirm your email address before signing in. '
          'Check your inbox for a confirmation link from us.',
          kind: AuthFailureKind.emailNotConfirmed,
        );
      }
    }

    if (_isSupabaseEmailOrAuthQuota(code) || _isSupabaseEmailOrAuthQuota(msg)) {
      return _emailQuotaMessage();
    }
    if (code.contains('rate') || msg.contains('too many')) {
      return const AuthException(
        'This action has been temporarily limited. Please wait briefly and try again.',
        kind: AuthFailureKind.rateLimited,
      );
    }

    return _fromPlainText(error.message, isSignUp: isSignUp);
  }

  return null;
}

bool _isSupabaseEmailOrAuthQuota(String s) {
  final t = s.toLowerCase();
  return t.contains('over_email_send_rate_limit') ||
      t.contains('email_rate_limit') ||
      t.contains('email rate limit') ||
      t.contains('email send rate') ||
      t.contains('429') && t.contains('email');
}

AuthException _emailQuotaMessage() {
  return const AuthException(
    'We couldn’t send that email just now. '
    'Please wait about an hour and try again, '
    'or continue with Google to sign in without waiting for email verification.',
    kind: AuthFailureKind.emailSendLimited,
  );
}
