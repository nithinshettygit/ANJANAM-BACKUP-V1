/// Standard API / auth error codes for blocked accounts.
abstract final class BlockedAccountCodes {
  static const userBlocked = 'USER_BLOCKED';
  static const adminBlocked = 'ADMIN_BLOCKED';
  static const accountDisabled = 'ACCOUNT_DISABLED';

  static const Set<String> all = {
    userBlocked,
    adminBlocked,
    accountDisabled,
    'user_blocked',
    'account_blocked',
    'admin_blocked',
  };

  static bool matches(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    return all.contains(raw.trim().toUpperCase()) ||
        all.contains(raw.trim().toLowerCase());
  }
}

/// User-facing copy for the restricted-account experience.
abstract final class BlockedAccountCopy {
  static const String screenTitle = 'Account Restricted';
  static const String screenMessage =
      'Your account has been temporarily blocked. Please contact support for assistance.';
}
