import 'package:ecommerce_app/core/auth/blocked_account_error_mapper.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';

/// Thrown after the app navigates to [AccountRestrictedPage] so callers skip raw error UI.
class AccountRestrictedSignal implements Exception {
  const AccountRestrictedSignal();
}

bool isAccountRestrictedError(Object? error) {
  if (error == null) return false;
  if (error is AccountRestrictedSignal) return true;
  if (error is AuthException && error.kind == AuthFailureKind.accountSuspended) {
    return true;
  }
  return BlockedAccountErrorMapper.tryParse(error) != null;
}
