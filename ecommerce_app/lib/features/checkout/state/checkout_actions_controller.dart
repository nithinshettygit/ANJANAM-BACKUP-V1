import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/state/cart_controller.dart';
import '../../order_history/domain/entities/order.dart';
import '../data/services/supabase_checkout_service.dart';
import '../domain/repositories/checkout_repository.dart';
import '../domain/shipping_details.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';

class CheckoutActionsController extends AsyncNotifier<Order?> {
  CheckoutRepository get _repo => SupabaseCheckoutService(
        ref.read(supabaseClientProvider),
        ref.read(cartRepositoryProvider),
      );

  @override
  Future<Order?> build() async {
    return null;
  }

  Future<Order> placeOrder({
    required ShippingDetails shipping,
    String? buyNowProductId,
    int buyNowQuantity = 1,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _repo.placeOrder(
        shipping: shipping,
        buyNowProductId: buyNowProductId,
        buyNowQuantity: buyNowQuantity,
      );
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final checkoutActionsProvider =
    AsyncNotifierProvider<CheckoutActionsController, Order?>(
  CheckoutActionsController.new,
);

