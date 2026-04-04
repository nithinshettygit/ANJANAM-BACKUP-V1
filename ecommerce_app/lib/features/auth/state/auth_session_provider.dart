import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import '../data/services/supabase_auth_service.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthService(ref.watch(supabaseClientProvider)),
);

/// Emits `null` when signed out, and `AppUser` when signed in.
final authSessionProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchAuthState(),
);

