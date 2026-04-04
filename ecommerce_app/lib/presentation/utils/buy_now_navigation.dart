import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/state/product_list_providers.dart';
import '../../features/product_details/state/product_details_providers.dart';

/// Opens buy-now checkout for [productId] **without** adding to the cart.
/// Cart and buy-now are separate: the server creates the order from the product
/// when it is not in the cart, or from the existing cart line when it is.
///
/// Refreshes storefront product cache first so stock shown on checkout matches the server
/// after admin inventory changes.
Future<void> openBuyNowCheckout(
  BuildContext context,
  WidgetRef ref, {
  required String productId,
  int quantity = 1,
}) async {
  ref.invalidate(productDetailsProvider(productId));
  ref.read(storefrontCatalogRevisionProvider.notifier).bump();
  if (!context.mounted) return;
  Navigator.of(context).pushNamed(
    '/checkout',
    arguments: <String, dynamic>{
      'productId': productId,
      'quantity': quantity < 1 ? 1 : quantity,
    },
  );
}
