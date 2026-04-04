import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/search/models/product_suggestion.dart';
import 'package:ecommerce_app/features/search/services/supabase_search_suggestions_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart' show Notifier;

final searchSuggestionsServiceProvider =
    Provider<SupabaseSearchSuggestionsService>((ref) {
  return SupabaseSearchSuggestionsService(ref.watch(supabaseClientProvider));
});

/// UI state for the storefront search field (debounced updates should call [requestSuggestions]).
class SearchSuggestionsUiState {
  final List<ProductSuggestion> suggestions;
  final bool loading;
  final String? errorMessage;
  /// Normalized query string these [suggestions] belong to (trimmed).
  final String? activeQuery;

  const SearchSuggestionsUiState({
    this.suggestions = const [],
    this.loading = false,
    this.errorMessage,
    this.activeQuery,
  });
}

/// Riverpod 3: use [Notifier], not `AutoDisposeNotifier` (removed). Auto-dispose comes from [NotifierProvider.autoDispose].
class SearchSuggestionsNotifier extends Notifier<SearchSuggestionsUiState> {
  int _generation = 0;
  String? _cachedQuery;
  List<ProductSuggestion>? _cachedSuggestions;

  @override
  SearchSuggestionsUiState build() => const SearchSuggestionsUiState();

  void clear() {
    _generation++;
    _cachedQuery = null;
    _cachedSuggestions = null;
    state = const SearchSuggestionsUiState();
  }

  /// Call after debouncing the raw text field value.
  Future<void> requestSuggestions(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) {
      clear();
      return;
    }
    if (q.length < SupabaseSearchSuggestionsService.kMinQueryLength) {
      _generation++;
      _cachedQuery = null;
      _cachedSuggestions = null;
      state = SearchSuggestionsUiState(activeQuery: q, suggestions: const []);
      return;
    }

    if (q == _cachedQuery && _cachedSuggestions != null) {
      state = SearchSuggestionsUiState(
        suggestions: _cachedSuggestions!,
        loading: false,
        activeQuery: q,
      );
      return;
    }

    final gen = ++_generation;
    state = SearchSuggestionsUiState(
      suggestions: state.suggestions,
      loading: true,
      activeQuery: q,
      errorMessage: null,
    );

    try {
      final list =
          await ref.read(searchSuggestionsServiceProvider).fetchSearchSuggestions(q);
      if (gen != _generation) return;
      _cachedQuery = q;
      _cachedSuggestions = list;
      state = SearchSuggestionsUiState(
        suggestions: list,
        loading: false,
        activeQuery: q,
      );
    } catch (e) {
      if (gen != _generation) return;
      _cachedQuery = null;
      _cachedSuggestions = null;
      state = SearchSuggestionsUiState(
        suggestions: const [],
        loading: false,
        activeQuery: q,
        errorMessage: e.toString(),
      );
    }
  }
}

final searchSuggestionsProvider =
    NotifierProvider.autoDispose<SearchSuggestionsNotifier, SearchSuggestionsUiState>(
  SearchSuggestionsNotifier.new,
);
