import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../models/product_suggestion.dart';

class SearchSuggestionItem extends StatelessWidget {
  const SearchSuggestionItem({
    super.key,
    required this.suggestion,
    required this.highlightQuery,
    required this.onTap,
    this.onTapDown,
  });

  final ProductSuggestion suggestion;
  final String highlightQuery;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;

  static IconData _iconFor(SuggestionMatchKind k) {
    switch (k) {
      case SuggestionMatchKind.titlePrefix:
      case SuggestionMatchKind.title:
        return Icons.shopping_bag_outlined;
      case SuggestionMatchKind.category:
        return Icons.category_outlined;
      case SuggestionMatchKind.description:
        return Icons.notes_outlined;
      case SuggestionMatchKind.tag:
        return Icons.label_outline_rounded;
      case SuggestionMatchKind.unknown:
        return Icons.search_rounded;
    }
  }

  String _matchChipLabel() {
    switch (suggestion.matchKind) {
      case SuggestionMatchKind.titlePrefix:
        return 'Title';
      case SuggestionMatchKind.title:
        return 'Title';
      case SuggestionMatchKind.category:
        final c = suggestion.categorySlug?.trim();
        if (c != null && c.isNotEmpty) return c;
        return 'Category';
      case SuggestionMatchKind.description:
        return 'Description';
      case SuggestionMatchKind.tag:
        return 'Tag / keyword';
      case SuggestionMatchKind.unknown:
        return 'Product';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needle = highlightQuery.trim().toLowerCase();
    final title = suggestion.name;
    final chipLabel = _matchChipLabel();

    return InkWell(
      onTapDown: (_) => onTapDown?.call(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _iconFor(suggestion.matchKind),
                size: 22,
                color: AppColors.brandSaffron.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  needle.isEmpty
                      ? Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        )
                      : _HighlightedTitle(
                          title: title,
                          needle: needle,
                          style: theme.textTheme.bodyLarge!,
                          highlightStyle: theme.textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandSaffronDeep,
                          ),
                        ),
                  const SizedBox(height: 6),
                  Text(
                    chipLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedTitle extends StatelessWidget {
  const _HighlightedTitle({
    required this.title,
    required this.needle,
    required this.style,
    required this.highlightStyle,
  });

  final String title;
  final String needle;
  final TextStyle style;
  final TextStyle highlightStyle;

  @override
  Widget build(BuildContext context) {
    final lower = title.toLowerCase();
    final idx = lower.indexOf(needle);
    if (idx < 0) {
      return Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    }
    final end = idx + needle.length;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: title.substring(0, idx)),
          TextSpan(
            text: title.substring(idx, end),
            style: highlightStyle,
          ),
          TextSpan(text: title.substring(end)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
