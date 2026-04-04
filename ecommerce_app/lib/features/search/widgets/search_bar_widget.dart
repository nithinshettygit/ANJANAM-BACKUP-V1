import 'package:ecommerce_app/presentation/widgets/storefront_home_header.dart';
import 'package:flutter/material.dart';

/// Storefront search field used in the search [AppBar] (and reusable elsewhere).
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.filledCapsule = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  /// Rounded filled field (e.g. dedicated search page).
  final bool filledCapsule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText ?? kStorefrontSearchHint,
            border: filledCapsule ? null : InputBorder.none,
            isDense: true,
            filled: filledCapsule,
            fillColor: filledCapsule
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
                : null,
            contentPadding: filledCapsule
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : null,
            enabledBorder: filledCapsule
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  )
                : null,
            focusedBorder: filledCapsule
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  )
                : null,
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  ),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        );
      },
    );
  }
}
