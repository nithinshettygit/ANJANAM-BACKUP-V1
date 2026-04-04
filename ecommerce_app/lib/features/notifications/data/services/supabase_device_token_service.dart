import 'package:supabase_flutter/supabase_flutter.dart';

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
    final uid = userId.trim();
    if (uid.isEmpty || token.isEmpty) return;

    try {
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

