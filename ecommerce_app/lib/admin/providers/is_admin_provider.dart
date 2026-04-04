import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'admin_providers.dart';

final isAdminProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(authSessionProvider);
  final user = session.asData?.value;
  if (user == null) return false;
  return ref.read(adminServiceProvider).isCurrentUserAdmin();
});
