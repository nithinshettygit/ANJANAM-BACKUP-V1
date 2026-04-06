import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

const String kBlockedAccountMessage =
    'Your account has been suspended. Please contact support for assistance.';

String blockedAccountMessageWithReason(String? reason) {
  final clean = reason?.trim() ?? '';
  if (clean.isEmpty) return kBlockedAccountMessage;
  return '$kBlockedAccountMessage Reason: $clean';
}

bool isBlockedStatusValue(String? rawStatus) {
  return (rawStatus ?? '').trim().toLowerCase() == 'blocked';
}

Future<void> ensureUserIsNotBlocked(
  SupabaseClient client, {
  required String userId,
  bool signOutIfBlocked = false,
  String blockedMessageFallback = kBlockedAccountMessage,
}) async {
  try {
    final row = await client
        .from('profiles')
        .select('status, blocked_reason')
        .eq('id', userId)
        .maybeSingle();
    if (!isBlockedStatusValue(row?['status']?.toString())) return;
    if (signOutIfBlocked) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    final blockedMessage = blockedAccountMessageWithReason(
      row?['blocked_reason']?.toString(),
    );
    throw AuthException(
      blockedMessage == kBlockedAccountMessage
          ? blockedMessageFallback
          : blockedMessage,
      kind: AuthFailureKind.accountSuspended,
    );
  } on AuthException {
    rethrow;
  } catch (_) {
    // If status lookup fails, do not block access solely due to transient read errors.
  }
}
