import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_notification.dart';

class AdminNotificationService {
  const AdminNotificationService(this.client);

  final SupabaseClient client;

  Future<List<AdminNotificationRow>> fetchNotifications({int limit = 50}) async {
    final rows = await client
        .from('admin_notifications')
        .select('id,type,title,message,reference_id,is_read,created_at,priority')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => AdminNotificationRow.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount() async {
    final rows = await client
        .from('admin_notifications')
        .select('id')
        .eq('is_read', false);
    return (rows as List).length;
  }

  Stream<List<AdminNotificationRow>> watchNotifications({int limit = 50}) {
    return client
        .from('admin_notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map((row) => AdminNotificationRow.fromJson(Map<String, dynamic>.from(row)))
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications(limit: 200).map(
      (rows) => rows.where((n) => !n.isRead).length,
    );
  }

  Future<void> markAsRead(String id) async {
    await client.from('admin_notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    await client.from('admin_notifications').update({'is_read': true}).eq('is_read', false);
  }
}

