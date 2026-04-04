import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

/// Base class for all services that perform Supabase calls.
abstract class SupabaseServiceBase {
  final SupabaseClient client;

  const SupabaseServiceBase(this.client);

  Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      // Keep error handling centralized; controllers/UI should never inspect raw Supabase errors.
      throw RepositoryException(e.toString());
    }
  }
}

