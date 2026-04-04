import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/state/product_list_providers.dart';
import '../../features/product_details/state/product_details_providers.dart';

/// Opens product details with a fresh fetch, then refreshes list providers when the user pops back
/// so admin stock changes are visible (Riverpod would otherwise keep cached [Product] rows).
Future<void> navigateToStorefrontProductDetails(
  BuildContext context,
  WidgetRef ref,
  String productId,
) async {
  ref.invalidate(productDetailsProvider(productId));
  await Navigator.of(context).pushNamed(
    '/catalog/details',
    arguments: productId,
  );
  if (context.mounted) {
    ref.read(storefrontCatalogRevisionProvider.notifier).bump();
  }
}
