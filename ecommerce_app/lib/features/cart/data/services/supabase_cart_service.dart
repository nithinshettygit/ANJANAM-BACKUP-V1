import 'package:ecommerce_app/core/constants/app_currency.dart';
import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../models/cart_item_model.dart';

/// Supabase-backed cart service (REST via Supabase PostgREST).
class SupabaseCartService extends SupabaseServiceBase
    implements CartRepository {
  SupabaseCartService(super.client);

  static bool _looksLikeHttp(String? value) {
    final v = value?.trim() ?? '';
    return v.startsWith('http://') || v.startsWith('https://');
  }

  static bool _isDefaultVariantRow(Map<String, dynamic> v) {
    final d = v['is_default'];
    if (d is bool) return d;
    if (d is num) return d != 0;
    final s = d?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static List<Map<String, dynamic>> _variantRows(
      Map<String, dynamic> productJson) {
    final embedded = productJson['product_variants'];
    if (embedded is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in embedded) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  /// Returns unit price, currency code, sellable stock, and resolved variant id (null = no variants).
  static ({
    double unitPrice,
    String currency,
    int? stock,
    String? resolvedVariantId,
  }) _pricingFromProductJson(
    Map<String, dynamic> productJson, {
    String? requestedVariantId,
  }) {
    final variants = _variantRows(productJson);
    if (variants.isEmpty) {
      final p = ProductModel.fromJson(productJson);
      return (
        unitPrice: p.price,
        currency: p.currency,
        stock: p.sellableQuantity,
        resolvedVariantId: null,
      );
    }

    Map<String, dynamic>? chosen;
    final req = requestedVariantId?.trim();
    if (req != null && req.isNotEmpty) {
      for (final v in variants) {
        if ((v['id'] ?? '').toString() == req) {
          chosen = v;
          break;
        }
      }
      if (chosen == null) {
        throw const ValidationException(
            'Selected option is not available for this product.');
      }
    } else {
      for (final v in variants) {
        if (_isDefaultVariantRow(v)) {
          chosen = v;
          break;
        }
      }
      chosen ??= variants.first;
    }

    final price = (chosen['price'] as num?)?.toDouble() ?? 0.0;
    final avail =
        ProductModel.inventoryCountFromJson(chosen['available_stock']);
    final inv = ProductModel.inventoryCountFromJson(chosen['stock_quantity']);
    final stock = avail ?? inv;
    return (
      unitPrice: price,
      currency: currencyOrInr(productJson['currency']),
      stock: stock,
      resolvedVariantId: (chosen['id'] ?? '').toString(),
    );
  }

  dynamic _cartLineQuery({
    required String cartId,
    required String productId,
    String? variantId,
  }) {
    var q = client
        .from('cart_items')
        .select('quantity')
        .eq('cart_id', cartId)
        .eq('product_id', productId);
    final v = variantId?.trim();
    if (v != null && v.isNotEmpty) {
      q = q.eq('variant_id', v);
    } else {
      q = q.filter('variant_id', 'is', null);
    }
    return q.limit(1);
  }

  dynamic _cartLineDeleteQuery({
    required String cartId,
    required String productId,
    String? variantId,
  }) {
    var q = client
        .from('cart_items')
        .delete()
        .eq('cart_id', cartId)
        .eq('product_id', productId);
    final v = variantId?.trim();
    if (v != null && v.isNotEmpty) {
      q = q.eq('variant_id', v);
    } else {
      q = q.filter('variant_id', 'is', null);
    }
    return q;
  }

  dynamic _cartLineUpdateQuery({
    required String cartId,
    required String productId,
    String? variantId,
    required int quantity,
  }) {
    var q = client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('cart_id', cartId)
        .eq('product_id', productId);
    final v = variantId?.trim();
    if (v != null && v.isNotEmpty) {
      q = q.eq('variant_id', v);
    } else {
      q = q.filter('variant_id', 'is', null);
    }
    return q;
  }

  @override
  Future<Cart> getCart() async {
    final cartId = await _ensureCartId();

    List<Map<String, dynamic>> itemsList;
    try {
      final itemsData = await guard(
        () => client
            .from('cart_items')
            .select(
              'cart_id, product_id, variant_id, quantity, unit_price, currency, created_at, '
              'products(title, image_urls), '
              'product_variants(variant_type, variant_name, image_url)',
            )
            .eq('cart_id', cartId)
            .order('created_at', ascending: false),
      );
      itemsList = (itemsData as List).cast<Map<String, dynamic>>();
    } catch (_) {
      final itemsData = await guard(
        () => client
            .from('cart_items')
            .select(
                'cart_id, product_id, variant_id, quantity, unit_price, currency, created_at')
            .eq('cart_id', cartId)
            .order('created_at', ascending: false),
      );
      itemsList = (itemsData as List).cast<Map<String, dynamic>>();
    }

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
            .select(
              'id, title, image_urls, inventory_count, available_stock, '
              'product_variants(id, stock_quantity, available_stock)',
            )
            .inFilter('id', productIds),
      );
      for (final row in (productsData as List).cast<Map<String, dynamic>>()) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) productById[id] = row;
      }

      final missingImageProductIds = productById.entries
          .where((e) {
            final urls = e.value['image_urls'];
            if (urls is List && urls.isNotEmpty) {
              final first = urls.first?.toString();
              return first == null || first.trim().isEmpty;
            }
            return true;
          })
          .map((e) => e.key)
          .toList();
      if (missingImageProductIds.isNotEmpty) {
        final articleRows = await guard(
          () => client
              .from('articles')
              .select('checkout_product_id, cover_image_url')
              .inFilter('checkout_product_id', missingImageProductIds),
        );
        for (final row in (articleRows as List).cast<Map<String, dynamic>>()) {
          final productId = (row['checkout_product_id'] ?? '').toString();
          if (productId.isEmpty) continue;
          final rawCover = row['cover_image_url']?.toString();
          if (rawCover == null || rawCover.trim().isEmpty) continue;
          final imageUrl = _looksLikeHttp(rawCover)
              ? rawCover
              : await client.storage
                  .from('articles')
                  .createSignedUrl(rawCover, 60 * 60);
          final existing = productById[productId];
          if (existing == null) continue;
          existing['image_urls'] = [imageUrl];
        }
      }
    }

    final items = <CartItem>[];
    for (final json in itemsList) {
      final itemModel = CartItemModel.fromJson(json);
      final row = productById[itemModel.productId];
      final product = row != null ? ProductModel.fromJson(row) : null;
      String? variantName;
      String? variantType;
      final pv = json['product_variants'];
      if (pv is Map) {
        final t = pv['variant_type']?.toString().trim();
        variantType = t != null && t.isNotEmpty ? t : null;
        final n = pv['variant_name']?.toString().trim();
        variantName = n != null && n.isNotEmpty ? n : null;
      }
      var imageUrls = product?.imageUrls ?? const <String>[];
      if (pv is Map) {
        final vi = pv['image_url']?.toString().trim();
        if (vi != null && vi.isNotEmpty) {
          imageUrls = [vi, ...imageUrls.where((u) => u != vi)];
        }
      }
      var title = product?.title ?? 'Product';
      if (variantName != null) {
        final variantLabel =
            variantType != null ? '$variantType: $variantName' : variantName;
        title = '$title · $variantLabel';
      }
      final availableStock = _stockForCartLine(
        row,
        variantId: itemModel.variantId,
      );
      items.add(
        itemModel.toEntity(
          title: title,
          imageUrls: imageUrls,
          variantName: variantName,
          availableStock: availableStock,
        ),
      );
    }

    return Cart(id: cartId, items: items, currency: currency);
  }

  static int? _stockForCartLine(
    Map<String, dynamic>? productJson, {
    required String? variantId,
  }) {
    if (productJson == null) return 0;
    final variants = _variantRows(productJson);
    final requestedVariant = variantId?.trim();
    if (requestedVariant != null && requestedVariant.isNotEmpty) {
      for (final variant in variants) {
        if ((variant['id'] ?? '').toString() == requestedVariant) {
          return ProductModel.inventoryCountFromJson(
                variant['available_stock'],
              ) ??
              ProductModel.inventoryCountFromJson(variant['stock_quantity']);
        }
      }
      return 0;
    }
    return ProductModel.inventoryCountFromJson(
            productJson['available_stock']) ??
        ProductModel.inventoryCountFromJson(productJson['inventory_count']);
  }

  @override
  Future<Cart> addItem({
    required String productId,
    required int quantity,
    String? variantId,
  }) async {
    if (quantity <= 0) {
      throw const ValidationException('Quantity must be greater than 0.');
    }

    final cartId = await _ensureCartId();

    late final Map<String, dynamic> productJson;
    try {
      final data = await guard(
        () => client
            .from('products')
            .select(
              'id, title, price, currency, image_urls, inventory_count, available_stock, '
              'product_variants(id, price, stock_quantity, available_stock, is_default, variant_name)',
            )
            .eq('id', productId)
            .eq('is_active', true)
            .single(),
      );
      productJson = Map<String, dynamic>.from(data as Map);
    } catch (_) {
      final data = await guard(
        () => client
            .from('products')
            .select(
                'id, title, price, currency, image_urls, inventory_count, available_stock')
            .eq('id', productId)
            .eq('is_active', true)
            .single(),
      );
      productJson = Map<String, dynamic>.from(data as Map);
    }

    final resolved =
        _pricingFromProductJson(productJson, requestedVariantId: variantId);
    final stock = resolved.stock;
    if (stock != null && stock <= 0) {
      throw const ValidationException('This product is out of stock.');
    }

    final existing = await guard(() => _cartLineQuery(
          cartId: cartId,
          productId: productId,
          variantId: resolved.resolvedVariantId,
        ));

    final existingList = (existing as List).cast<Map<String, dynamic>>();
    if (existingList.isEmpty) {
      if (stock != null && quantity > stock) {
        throw const ValidationException('Requested quantity is not available.');
      }
      await guard(
        () => client.from('cart_items').insert({
          'cart_id': cartId,
          'product_id': productId,
          if (resolved.resolvedVariantId != null)
            'variant_id': resolved.resolvedVariantId,
          'quantity': quantity,
          'unit_price': resolved.unitPrice,
          'currency': resolved.currency,
        }),
      );
    } else {
      final existingQty =
          (existingList.first['quantity'] as num?)?.toInt() ?? 0;
      final newQty = existingQty + quantity;
      if (stock != null && newQty > stock) {
        throw const ValidationException('Requested quantity is not available.');
      }

      await guard(
        () => _cartLineUpdateQuery(
          cartId: cartId,
          productId: productId,
          variantId: resolved.resolvedVariantId,
          quantity: newQty,
        ),
      );
    }

    return getCart();
  }

  @override
  Future<Cart> updateQuantity({
    required String productId,
    String? variantId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return removeItem(productId: productId, variantId: variantId);
    }

    final cartId = await _ensureCartId();

    late final Map<String, dynamic> productJson;
    try {
      final data = await guard(
        () => client
            .from('products')
            .select(
              'id, inventory_count, available_stock, '
              'product_variants(id, stock_quantity, available_stock)',
            )
            .eq('id', productId)
            .eq('is_active', true)
            .single(),
      );
      productJson = Map<String, dynamic>.from(data as Map);
    } catch (_) {
      final data = await guard(
        () => client
            .from('products')
            .select('id, inventory_count, available_stock')
            .eq('id', productId)
            .eq('is_active', true)
            .single(),
      );
      productJson = Map<String, dynamic>.from(data as Map);
    }

    if (_variantRows(productJson).isNotEmpty &&
        (variantId == null || variantId.trim().isEmpty)) {
      throw const ValidationException(
          'Missing product variant for this cart line.');
    }

    final resolved =
        _pricingFromProductJson(productJson, requestedVariantId: variantId);
    final stock = resolved.stock;
    if (stock != null && quantity > stock) {
      throw const ValidationException('Requested quantity is not available.');
    }

    await guard(
      () => _cartLineUpdateQuery(
        cartId: cartId,
        productId: productId,
        variantId: resolved.resolvedVariantId,
        quantity: quantity,
      ),
    );
    return getCart();
  }

  @override
  Future<Cart> removeItem({
    required String productId,
    String? variantId,
  }) async {
    final cartId = await _ensureCartId();

    try {
      final data = await guard(
        () => client
            .from('products')
            .select('id, product_variants(id)')
            .eq('id', productId)
            .eq('is_active', true)
            .single(),
      );
      final pj = Map<String, dynamic>.from(data as Map);
      if (_variantRows(pj).isNotEmpty &&
          (variantId == null || variantId.trim().isEmpty)) {
        throw const ValidationException(
            'Missing product variant for this cart line.');
      }
    } catch (e) {
      if (e is ValidationException) rethrow;
    }

    await guard(
      () => _cartLineDeleteQuery(
          cartId: cartId, productId: productId, variantId: variantId),
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
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );

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
          .insert({'user_id': userId})
          .select('id')
          .single(),
    );

    return created['id'].toString();
  }
}
