import 'package:ecommerce_app/core/auth/account_restricted_signal.dart';
import 'package:ecommerce_app/core/auth/blocked_account_codes.dart';
import 'package:ecommerce_app/core/auth/blocked_account_error_mapper.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';

/// Short copy for SnackBars and simple alerts (avoids raw repository dumps).
String userFacingErrorMessage(Object error) {
  if (error is AccountRestrictedSignal) {
    return BlockedAccountCopy.screenMessage;
  }
  final blocked = BlockedAccountErrorMapper.tryParse(error);
  if (blocked != null) return blocked.userMessage;
  if (error is AppException) return error.message;
  final raw = error.toString().trim();
  if (raw.length > 220 || _looksTechnical(raw)) {
    return 'Something went wrong. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

bool shouldSuppressErrorSnackBar(Object error) => isAccountRestrictedError(error);

bool _looksTechnical(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('postgrest') ||
      lower.contains('exception') ||
      lower.contains('violates') ||
      lower.contains('pgrst') ||
      lower.contains('row-level security');
}
