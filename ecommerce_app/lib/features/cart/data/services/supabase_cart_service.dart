import 'package:ecommerce_app/core/constants/app_currency.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../models/cart_item_model.dart';

/// Supabase-backed cart service (REST via Supabase PostgREST).
class SupabaseCartService extends SupabaseServiceBase implements CartRepository {
  SupabaseCartService(super.client);

  @override
  Future<Cart> getCart() async {
    final cartId = await _ensureCartId();

    final itemsData = await guard(
      () => client
          .from('cart_items')
          .select('cart_id, product_id, quantity, unit_price, currency')
          .eq('cart_id', cartId)
          .order('created_at', ascending: false),
    );

    final itemsList = (itemsData as List).cast<Map<String, dynamic>>();
    if (itemsList.isEmpty) {
      return Cart(id: cartId, items: const [], currency: kAppCurrencyCode);
    }

    final currency = currencyOrInr(itemsList.first['currency']);

    final productIds = itemsList
        .map((e) => (e['product_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final productById = <String, Map<String, dynamic>>{};
    if (productIds.isNotEmpty) {
      final productsData = await guard(
        () => client
            .from('products')
            .select('id, title, image_urls')
            .inFilter('id', productIds),
      );
      for (final row in (productsData as List).cast<Map<String, dynamic>>()) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) productById[id] = row;
      }
    }

    final items = <CartItem>[];
    for (final json in itemsList) {
      final itemModel = CartItemModel.fromJson(json);
      final row = productById[itemModel.productId];
      final product = row != null ? ProductModel.fromJson(row) : null;
      items.add(
        itemModel.toEntity(
          title: product?.title ?? 'Product',
          imageUrls: product?.imageUrls ?? const [],
        ),
      );
    }

    return Cart(id: cartId, items: items, currency: currency);
  }

  @override
  Future<Cart> addItem({
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      throw const ValidationException('Quantity must be greater than 0.');
    }

    final cartId = await _ensureCartId();

    final productJson = await guard(
      () => client
          .from('products')
          .select('id, title, price, currency, image_urls, inventory_count, available_stock')
          .eq('id', productId)
          .eq('is_active', true)
          .single(),
    );
    final product = ProductModel.fromJson(productJson);
    final stock = product.sellableQuantity;
    if (stock != null && stock <= 0) {
      throw const ValidationException('This product is out of stock.');
    }

    final existing = await guard(
      () => client
          .from('cart_items')
          .select('quantity')
          .eq('cart_id', cartId)
          .eq('product_id', productId)
          .limit(1),
    );

    final existingList = (existing as List).cast<Map<String, dynamic>>();
    if (existingList.isEmpty) {
      if (stock != null && quantity > stock) {
        throw ValidationException('Only $stock available in stock.');
      }
      await guard(
        () => client.from('cart_items').insert({
              'cart_id': cartId,
              'product_id': productId,
              'quantity': quantity,
              'unit_price': product.price,
              'currency': product.currency,
            }),
      );
    } else {
      final existingQty = (existingList.first['quantity'] as num?)?.toInt() ?? 0;
      final newQty = existingQty + quantity;
      if (stock != null && newQty > stock) {
        throw ValidationException('Only $stock available in stock.');
      }

      await guard(
        () => client
            .from('cart_items')
            .update({'quantity': newQty}).eq('cart_id', cartId).eq('product_id', productId),
      );
    }

    return getCart();
  }

  @override
  Future<Cart> updateQuantity({
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return removeItem(productId: productId);
    }

    final cartId = await _ensureCartId();

    final productJson = await guard(
      () => client
          .from('products')
          .select('inventory_count, available_stock')
          .eq('id', productId)
          .eq('is_active', true)
          .single(),
    );
    final tmp = ProductModel.fromJson(productJson);
    final stock = tmp.sellableQuantity;
    if (stock != null && quantity > stock) {
      throw ValidationException('Only $stock available in stock.');
    }

    await guard(
      () => client
          .from('cart_items')
          .update({'quantity': quantity}).eq('cart_id', cartId).eq('product_id', productId),
    );
    return getCart();
  }

  @override
  Future<Cart> removeItem({
    required String productId,
  }) async {
    final cartId = await _ensureCartId();
    await guard(
      () => client
          .from('cart_items')
          .delete()
          .eq('cart_id', cartId)
          .eq('product_id', productId),
    );
    return getCart();
  }

  @override
  Future<void> clearCart() async {
    final cartId = await _ensureCartId();
    await guard(
      () => client.from('cart_items').delete().eq('cart_id', cartId),
    );
  }

  Future<String> _ensureCartId() async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required to manage cart.');
    }

    final userId = authUser.id;

    final existing = await guard(
      () => client.from('carts').select('id').eq('user_id', userId).limit(1),
    );
    final existingList = (existing as List).cast<Map<String, dynamic>>();
    if (existingList.isNotEmpty) {
      return existingList.first['id'].toString();
    }

    final created = await guard(
      () => client
          .from('carts')
          .insert({'user_id': userId}).select('id')
          .single(),
    );

    return created['id'].toString();
  }
}

