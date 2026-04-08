import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../models/product_suggestion.dart';
import 'search_suggestion_item.dart';

/// Constrained-height list under the search field.
class SearchSuggestionsList extends StatelessWidget {
  const SearchSuggestionsList({
    super.key,
    required this.query,
    required this.suggestions,
    required this.loading,
    required this.onSuggestionTap,
    this.onSuggestionTapDown,
    this.errorMessage,
    this.maxHeight = 280,
  });

  final String query;
  final List<ProductSuggestion> suggestions;
  final bool loading;
  final String? errorMessage;
  final ValueChanged<ProductSuggestion> onSuggestionTap;
  final ValueChanged<ProductSuggestion>? onSuggestionTapDown;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = query.trim();
    if (q.length < 2) return const SizedBox.shrink();

    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: AppColors.surfaceCard,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: loading && suggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.brandSaffron,
                    ),
                  ),
                ),
              )
            : errorMessage != null && errorMessage!.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load suggestions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  )
                : suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No suggestions found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.dividerColor.withValues(alpha: 0.25),
                        ),
                        itemBuilder: (context, i) {
                          final s = suggestions[i];
                          return SearchSuggestionItem(
                            suggestion: s,
                            highlightQuery: q,
                            onTapDown: onSuggestionTapDown == null
                                ? null
                                : () => onSuggestionTapDown!(s),
                            onTap: () => onSuggestionTap(s),
                          );
                        },
                      ),
      ),
    );
  }
}
