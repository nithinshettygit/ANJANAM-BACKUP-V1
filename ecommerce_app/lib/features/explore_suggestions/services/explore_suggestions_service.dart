import 'dart:typed_data';

import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../models/explore_suggestion.dart';

class ExploreSuggestionsService extends SupabaseServiceBase {
  ExploreSuggestionsService(super.client);

  Future<String> uploadSuggestionImage({
    required Uint8List bytes,
    required String fileName,
    String folder = 'explore_suggestions',
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final safeFolder = folder.replaceAll(RegExp(r'[^\w\-]'), '');
    final objectPath = '$safeFolder/${stamp}_$sanitized';
    await guard(
      () => client.storage.from('product-images').uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          ),
    );
    return client.storage.from('product-images').getPublicUrl(objectPath);
  }

  Future<List<ExploreSuggestion>> fetchActiveSuggestions({int limit = 12}) async {
    final data = await guard(
      () => client
          .from('explore_suggestions')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false)
          .range(0, limit - 1),
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ExploreSuggestion.fromRow)
        .toList();
  }

  Future<List<ExploreSuggestion>> fetchAdminSuggestions({int limit = 100}) async {
    final data = await guard(
      () => client
          .from('explore_suggestions')
          .select()
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false)
          .range(0, limit - 1),
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ExploreSuggestion.fromRow)
        .toList();
  }

  Future<void> insertSuggestion(Map<String, dynamic> row) async {
    await guard(() => client.from('explore_suggestions').insert(row));
  }

  Future<void> updateSuggestion(String id, Map<String, dynamic> row) async {
    await guard(() => client.from('explore_suggestions').update(row).eq('id', id));
  }

  Future<void> deleteSuggestion(String id) async {
    await guard(() => client.from('explore_suggestions').delete().eq('id', id));
  }

  Future<void> reorderSuggestions(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await guard(
        () => client.from('explore_suggestions').update({'sort_order': i}).eq('id', ids[i]),
      );
    }
  }
}
