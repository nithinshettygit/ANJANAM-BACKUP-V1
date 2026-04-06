import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/explore_suggestion.dart';
import '../services/explore_suggestions_service.dart';

final exploreSuggestionsServiceProvider = Provider<ExploreSuggestionsService>(
  (ref) => ExploreSuggestionsService(ref.watch(supabaseClientProvider)),
);

final exploreSuggestionsRevisionProvider =
    NotifierProvider<ExploreSuggestionsRevisionNotifier, int>(
  ExploreSuggestionsRevisionNotifier.new,
);

class ExploreSuggestionsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final activeExploreSuggestionsProvider =
    FutureProvider.autoDispose<List<ExploreSuggestion>>((ref) async {
  ref.watch(exploreSuggestionsRevisionProvider);
  return ref.watch(exploreSuggestionsServiceProvider).fetchActiveSuggestions();
});

final adminExploreSuggestionsProvider =
    FutureProvider.autoDispose<List<ExploreSuggestion>>((ref) async {
  return ref.watch(exploreSuggestionsServiceProvider).fetchAdminSuggestions();
});
