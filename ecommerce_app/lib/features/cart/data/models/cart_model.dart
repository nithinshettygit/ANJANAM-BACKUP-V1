import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_item.dart';

/// Data model mapped directly to the `carts` table.
class CartModel {
  final String id;
  final String userId;

  const CartModel({
    required this.id,
    required this.userId,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
      };

  Cart toEntity({
    required String currency,
    required List<CartItem> items,
  }) {
    return Cart(
      id: id,
      items: items,
      currency: currency,
    );
  }
}

