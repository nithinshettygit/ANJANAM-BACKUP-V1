import 'package:ecommerce_app/core/auth/blocked_account_codes.dart';
import 'package:ecommerce_app/core/auth/blocked_account_error_mapper.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

const String kBlockedAccountMessage = BlockedAccountCopy.screenMessage;

String blockedAccountMessageWithReason(String? reason) {
  final clean = reason?.trim() ?? '';
  if (clean.isEmpty) return kBlockedAccountMessage;
  return '$kBlockedAccountMessage\n\nReason: $clean';
}

bool isBlockedStatusValue(String? rawStatus) {
  return (rawStatus ?? '').trim().toLowerCase() == 'blocked';
}

Future<BlockedAccountDetection?> fetchOwnAccountRestriction(
  SupabaseClient client, {
  String? userId,
}) async {
  try {
    final uid = userId ?? client.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await client.rpc(
      'get_own_account_restriction',
      params: {'uid': uid},
    );
    if (res is! Map) return null;
    return BlockedAccountErrorMapper.fromRestrictionRpc(
      Map<String, dynamic>.from(res),
    );
  } catch (_) {
    return null;
  }
}

Future<void> ensureUserIsNotBlocked(
  SupabaseClient client, {
  required String userId,
  bool signOutIfBlocked = false,
  String blockedMessageFallback = kBlockedAccountMessage,
}) async {
  try {
    final detection = await fetchOwnAccountRestriction(client, userId: userId);
    if (detection == null) {
      // Fallback when RPC is not deployed yet.
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
      throw AuthException(
        blockedAccountMessageWithReason(row?['blocked_reason']?.toString()),
        kind: AuthFailureKind.accountSuspended,
      );
    }

    if (signOutIfBlocked) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    final message = detection.userMessage == BlockedAccountCopy.screenMessage
        ? blockedMessageFallback
        : detection.userMessage;
    throw detection.copyWith(userMessage: message).toAuthException();
  } on AuthException {
    rethrow;
  } catch (_) {
    // Transient lookup failures must not block access solely due to read errors.
  }
}
