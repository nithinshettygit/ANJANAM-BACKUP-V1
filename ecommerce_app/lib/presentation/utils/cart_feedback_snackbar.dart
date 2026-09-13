import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_shell_navigation.dart';
import 'package:ecommerce_app/l10n/app_localizations.dart';

/// Auto-dismiss timing similar to typical e‑commerce apps (e.g. Flipkart).
const Duration _kAddedToCartSnackDuration = Duration(seconds: 3);

/// Ensures a prior add-to-cart backup timer cannot dismiss a newer snackbar.
Timer? _cartSnackBackupTimer;

/// Shows a short snackbar. Removes any current snackbar first, then shows after
/// a microtask so the dismiss timer always starts (avoids M3 / messenger races).
///
/// Uses an inline [TextButton] instead of [SnackBarAction]: on some Material 3 /
/// Android builds, snackbars with [SnackBarAction] never auto-dismiss and only
/// leave via swipe. A delayed [ScaffoldMessenger.hideCurrentSnackBar] enforces
/// dismissal after [_kAddedToCartSnackDuration].
void showAddedToCartSnackBar(
  WidgetRef ref,
  BuildContext context, {
  String? productTitle,
}) {
    final localizations = AppLocalizations.of(context);
    final text = productTitle != null && productTitle.isNotEmpty
      ? localizations.addedToCart(productTitle)
      : localizations.addedToCartGeneric;
  final messenger = ScaffoldMessenger.of(context);
  _cartSnackBackupTimer?.cancel();
  _cartSnackBackupTimer = null;
  messenger.removeCurrentSnackBar();
  final snackBar = SnackBar(
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        TextButton(
          onPressed: () {
            _cartSnackBackupTimer?.cancel();
            _cartSnackBackupTimer = null;
            messenger.hideCurrentSnackBar();
            navigateToCartPage(ref, context);
          },
          child: Text(localizations.goToCart),
        ),
      ],
    ),
    duration: _kAddedToCartSnackDuration,
    behavior: SnackBarBehavior.fixed,
    dismissDirection: DismissDirection.horizontal,
  );

  unawaited(
    Future<void>.microtask(() {
      if (!context.mounted) return;
      messenger.showSnackBar(snackBar);
      _cartSnackBackupTimer = Timer(_kAddedToCartSnackDuration, () {
        _cartSnackBackupTimer = null;
        if (!context.mounted) return;
        messenger.hideCurrentSnackBar();
      });
    }),
  );
}
