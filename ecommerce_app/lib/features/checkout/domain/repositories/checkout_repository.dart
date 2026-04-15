import '../../../order_history/domain/entities/order.dart';
import '../shipping_details.dart';

abstract class CheckoutRepository {
  /// Places an order using the current cart for the signed-in user.
  ///
  /// When [buyNowProductId] is set, only that cart line is ordered and removed
  /// from the cart; other cart lines stay untouched.
  /// When [buyNowProductId] is set and the product is not in the cart, [buyNowQuantity] is used.
  Future<Order> placeOrder({
    required ShippingDetails shipping,
    String? buyNowProductId,
    String? buyNowVariantId,
    int buyNowQuantity = 1,
  });
}

