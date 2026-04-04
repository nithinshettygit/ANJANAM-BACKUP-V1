import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_shell_navigation.dart';

/// Auto-dismiss timing similar to typical e‑commerce apps (e.g. Flipkart).
const Duration _kAddedToCartSnackDuration = Duration(seconds: 3);

/// Shows a short snackbar. Removes any current snackbar first, then shows after
/// a microtask so the dismiss timer always starts (avoids M3 / messenger races).
void showAddedToCartSnackBar(
  WidgetRef ref,
  BuildContext context, {
  String? productTitle,
}) {
  final text = productTitle != null && productTitle.isNotEmpty
      ? '$productTitle added to cart'
      : 'Added to cart';
  final messenger = ScaffoldMessenger.of(context);
  messenger.removeCurrentSnackBar();
  final snackBar = SnackBar(
    content: Text(text),
    duration: _kAddedToCartSnackDuration,
    behavior: SnackBarBehavior.fixed,
    dismissDirection: DismissDirection.horizontal,
    action: SnackBarAction(
      label: 'Go to Cart',
      onPressed: () {
        messenger.removeCurrentSnackBar();
        navigateToCartPage(ref, context);
      },
    ),
  );

  Future<void>.microtask(() {
    if (!context.mounted) return;
    messenger.showSnackBar(snackBar);
  });
}
