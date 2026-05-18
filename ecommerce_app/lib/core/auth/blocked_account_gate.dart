import 'package:ecommerce_app/core/auth/account_restricted_signal.dart';
import 'package:ecommerce_app/core/auth/blocked_account_error_mapper.dart';
import 'package:ecommerce_app/core/notifications/notification_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global handler for blocked-account detection → restricted screen navigation.
class BlockedAccountGate {
  BlockedAccountGate(Ref ref);

  bool _presenting = false;
  bool _restrictedRouteVisible = false;

  static BlockedAccountGate? _instance;

  static void install(Ref ref) {
    _instance = BlockedAccountGate(ref);
  }

  static BlockedAccountGate? get instance => _instance;

  /// Returns true when navigation to the restricted screen was triggered.
  static Future<bool> handleIfBlocked(Object error) async {
    final gate = _instance;
    if (gate == null) return false;
    return gate._handleIfBlocked(error);
  }

  Future<bool> _handleIfBlocked(Object error) async {
    if (_restrictedRouteVisible || _presenting) return true;

    var detection = BlockedAccountErrorMapper.tryParse(error);
    if (detection == null) {
      final hasSession = Supabase.instance.client.auth.currentUser != null;
      if (hasSession &&
          (BlockedAccountErrorMapper.looksLikeAccessPolicyDenial(error) ||
              error is PostgrestException)) {
        detection = await _tryServerRestrictionStatus();
      }
    }

    if (detection == null) return false;

    await presentRestricted(detection: detection);
    return true;
  }

  Future<BlockedAccountDetection?> _tryServerRestrictionStatus() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final res = await client.rpc('get_own_account_restriction');
      if (res is! Map) return null;
      return BlockedAccountErrorMapper.fromRestrictionRpc(
        Map<String, dynamic>.from(res),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('BlockedAccountGate: restriction RPC failed: $e\n$st');
      }
      return null;
    }
  }

  Future<void> presentRestricted({
    BlockedAccountDetection? detection,
    String? message,
    String? blockedReason,
  }) async {
    if (_restrictedRouteVisible || _presenting) return;
    _presenting = true;
    try {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      final nav = notificationNavigatorKey.currentState;
      if (nav == null || !nav.mounted) return;

      _restrictedRouteVisible = true;
      await nav.pushNamedAndRemoveUntil(
        '/account-restricted',
        (_) => false,
        arguments: <String, String?>{
          'message': message ?? detection?.userMessage,
          'blockedReason': blockedReason ?? detection?.blockedReason,
          'errorCode': detection?.errorCode,
        },
      );
    } finally {
      _presenting = false;
    }
  }

  void markRestrictedRouteClosed() {
    _restrictedRouteVisible = false;
  }

  /// Used by [NetworkRequestGuard] and other centralized callers.
  static Future<void> rethrowIfHandled(Object error) async {
    final handled = await handleIfBlocked(error);
    if (handled) throw const AccountRestrictedSignal();
  }
}

final blockedAccountGateProvider = Provider<BlockedAccountGate>((ref) {
  if (BlockedAccountGate.instance == null) {
    BlockedAccountGate.install(ref);
  }
  return BlockedAccountGate.instance!;
});
