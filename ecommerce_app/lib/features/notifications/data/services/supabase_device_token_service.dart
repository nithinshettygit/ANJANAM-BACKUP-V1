import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';

class SupabaseDeviceTokenService extends SupabaseServiceBase {
  const SupabaseDeviceTokenService(super.client);

  /// Stores/updates the FCM token for the given user.
  ///
  /// We intentionally do this with a best-effort select+insert/update to avoid
  /// depending on PostgREST upsert syntax.
  Future<void> upsertDeviceToken({
    required String userId,
    required String fcmToken,
    required String deviceType,
  }) async {
    final token = fcmToken.trim();
    // Match Edge Function / Postgres UUID lookups (avoids mixed-case user_id mismatches).
    final uid = userId.trim().toLowerCase();
    if (uid.isEmpty || token.isEmpty) return;

    try {
      // Preferred path: SECURITY DEFINER RPC that rebinds token ownership to
      // current authenticated user (fixes stale cross-account token delivery).
      try {
        await client.rpc('register_my_device_token', params: {
          'p_fcm_token': token,
          'p_device_type': deviceType,
        });
        return;
      } catch (_) {
        // Fallback to legacy flow when RPC migration is not applied yet.
      }

      // Keep a latest pointer on profiles for server-side per-user lookups.
      // If this fails due to schema/policy mismatch, continue with user_devices.
      try {
        await client.from('profiles').update({
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('FCM token sync (profiles) failed: $e');
        }
      }

      // `fcm_token` is globally unique. If the same token already exists for
      // another user/session, rebind it to the current user.
      final existing = await client
          .from('user_devices')
          .select('id,user_id')
          .eq('fcm_token', token)
          .maybeSingle();

      if (existing != null) {
        await client.from('user_devices').update({
          'user_id': uid,
          'device_type': deviceType,
        }).eq('fcm_token', token);
      } else {
        await client.from('user_devices').insert({
          'user_id': uid,
          'fcm_token': token,
          'device_type': deviceType,
        });
      }
    } on PostgrestException catch (_) {
      // Avoid breaking app when DB schema is not yet migrated.
    } catch (_) {
      // Best-effort token sync; never block startup.
    }
  }
}

