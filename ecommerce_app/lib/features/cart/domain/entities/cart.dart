import 'package:flutter/foundation.dart';

import 'cart_item.dart';

class Cart {
  final String id;
  final List<CartItem> items;
  final String currency;

  const Cart({
    required this.id,
    required this.items,
    required this.currency,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get total => subtotal;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Cart &&
            id == other.id &&
            currency == other.currency &&
            listEquals(items, other.items);
  }

  @override
  int get hashCode => Object.hash(id, currency, Object.hashAll(items));
}

