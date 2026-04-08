import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client_provider.dart';
import '../domain/admin_notification.dart';
import '../services/admin_notification_service.dart';

final adminNotificationServiceProvider = Provider<AdminNotificationService>(
  (ref) => AdminNotificationService(ref.watch(supabaseClientProvider)),
);

final adminNotificationsProvider = StreamProvider<List<AdminNotificationRow>>(
  (ref) => ref.watch(adminNotificationServiceProvider).watchNotifications(),
);

final adminUnreadNotificationsCountProvider = StreamProvider<int>(
  (ref) => ref.watch(adminNotificationServiceProvider).watchUnreadCount(),
);

final adminRecentNotificationsProvider = StreamProvider<List<AdminNotificationRow>>(
  (ref) => ref.watch(adminNotificationServiceProvider).watchNotifications(limit: 5),
);

