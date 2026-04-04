import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_actions_controller.dart';
import '../features/catalog/state/product_list_providers.dart';
import '../features/cart/state/cart_controller.dart';

/// Simple backend smoke test to validate:
/// 1) product fetching
/// 2) authentication
/// 3) cart creation + cart item insertion
///
/// Note: run this only in dev. Requires valid `SUPABASE_URL` and `SUPABASE_ANON_KEY`,
/// and a Supabase project with the schema/migrations applied.
Future<void> backendSmokeTest({
  required ProviderContainer container,
  required String email,
  required String password,
}) async {
  // 1) Product fetching (public select should be allowed by RLS)
  final productsState = await container.read(
    productListProvider(ProductListQuery(limit: 5, offset: 0)).future,
  );

  if (productsState.isEmpty) {
    throw StateError('No products returned. Check products RLS + seed data.');
  }

  // 2) Authentication
  await container
      .read(authActionsProvider.notifier)
      .signIn(email: email, password: password);

  // 3) Cart + cart item insertion (authenticated + cart RLS)
  await container.read(cartControllerProvider.future);

  await container.read(cartControllerProvider.notifier).addItem(
        productId: productsState.first.id,
        quantity: 1,
      );

  final updatedCart = await container.read(cartControllerProvider.future);
  if (updatedCart.items.isEmpty) {
    throw StateError('Cart item insertion failed. Check cart_items RLS.');
  }
}

