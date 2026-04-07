import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.resolve());

/// Single SupabaseClient instance for the whole app.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  ref.watch(appEnvProvider);
  return Supabase.instance.client;
});

