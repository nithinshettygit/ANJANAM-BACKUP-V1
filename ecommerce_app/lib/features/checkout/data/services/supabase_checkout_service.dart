import 'package:ecommerce_app/core/checkout/checkout_telemetry.dart';
import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/domain/repositories/cart_repository.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../../catalog/domain/entities/product_variant.dart';
import '../../../order_history/data/models/order_item_model.dart';
import '../../../order_history/domain/entities/order.dart';
import '../../../order_history/domain/entities/order_item.dart';
import '../../domain/checkout_pricing_rules.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../domain/shipping_details.dart';

/// Supabase-backed checkout service.
class SupabaseCheckoutService extends SupabaseServiceBase
    implements CheckoutRepository {
  SupabaseCheckoutService(super.client, this._cartRepository);

  final CartRepository _cartRepository;

  /// Legacy client inserts trust cart prices and skip reservation — off by default
  /// in **all** build modes. Emergency only: `--dart-define=ALLOW_LEGACY_CHECKOUT=true`
  static const bool _allowLegacyCheckout = bool.fromEnvironment(
    'ALLOW_LEGACY_CHECKOUT',
    defaultValue: false,
  );

  static bool get _legacyCheckoutFallbackEnabled => _allowLegacyCheckout;

  /// PostgREST / Postgres signals that the RPC is missing or not exposed.
  static bool _isRpcMissingPostgrest(PostgrestException e) {
    final combined =
        '${e.message} ${e.details ?? ''} ${e.code ?? ''}'.toLowerCase();
    return combined.contains('42883') ||
        combined.contains('pgrst202') ||
        (combined.contains('place_order_checkout') &&
            combined.contains('does not exist')) ||
        combined.contains('could not find the function');
  }

  /// Merge duplicate cart lines that share the same product and variant.
  static List<CartItem> _mergeLinesByProductAndVariant(List<CartItem> items) {
    final map = <String, CartItem>{};
    for (final e in items) {
      final key = '${e.productId}|${e.variantId ?? ''}';
      final existing = map[key];
      if (existing == null) {
        map[key] = e;
      } else {
        map[key] = CartItem(
          productId: e.productId,
          variantId: e.variantId,
          variantName: e.variantName ?? existing.variantName,
          title: existing.title,
          imageUrls: existing.imageUrls,
          unitPrice: existing.unitPrice,
          currency: existing.currency,
          quantity: existing.quantity + e.quantity,
        );
      }
    }
    return map.values.toList();
  }

  static Map<String, dynamic> _parseRpcOrderRow(dynamic inserted) {
    if (inserted is List) {
      if (inserted.isEmpty) {
        throw const RepositoryException('Checkout returned no order.');
      }
      final first = inserted.first;
      if (first is! Map) {
        throw RepositoryException('Checkout returned invalid row: $first');
      }
      return Map<String, dynamic>.from(first);
    }
    if (inserted is Map) {
      return Map<String, dynamic>.from(inserted);
    }
    throw RepositoryException(
      'Unexpected checkout response: ${inserted.runtimeType}',
    );
  }

  static bool _isMissingCheckoutRpcError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('42883') ||
        s.contains('pgrst202') ||
        (s.contains('place_order_checkout') && s.contains('does not exist')) ||
        s.contains('could not find the function');
  }

  static String _rpcUserMessage(PostgrestException e) {
    final m = e.message.toLowerCase();
    if (m.contains('insufficient_inventory')) {
      return 'Not enough stock for one or more items.';
    }
    if (m.contains('product_not_found')) {
      return 'A product in your order is no longer available.';
    }
    if (m.contains('not_authenticated')) {
      return 'Sign in required to checkout.';
    }
    if (m.contains('empty_cart')) {
      return 'Your order has no items.';
    }
    if (m.contains('invalid_quantity')) {
      return 'Invalid quantity in your order.';
    }
    if (m.contains('shipping_required')) {
      return 'Shipping address is required.';
    }
    if (m.contains('invalid_shipping_phone')) {
      return 'Invalid phone number (use 10 digits).';
    }
    if (m.contains('invalid_shipping_postal')) {
      return 'Invalid PIN code (use 6 digits).';
    }
    if (m.contains('invalid_shipping')) {
      return 'Please check your shipping details.';
    }
    if (m.contains('product_not_available')) {
      return 'A product in your order is not available for purchase.';
    }
    if (m.contains('currency_mismatch')) {
      return 'Your cart mixes currencies; remove items and try again.';
    }
    if (m.contains('cod_not_allowed')) {
      return 'This product is available only via online payment.';
    }
    if (m.contains('invalid_product_id')) {
      return 'Invalid product in your order.';
    }
    if (m.contains('invalid_product_price')) {
      return 'A product price could not be applied. Try again or contact support.';
    }
    if (m.contains('product_tax_configuration_incomplete')) {
      return 'A product tax configuration needs admin review before it can be purchased.';
    }
    if (m.contains('variant_required')) {
      return 'Please choose a product option (size/weight/color) for each item.';
    }
    if (m.contains('variant_not_found') || m.contains('invalid_variant_id')) {
      return 'A selected product option is no longer available.';
    }
    if (m.contains('variant_not_applicable')) {
      return 'This product does not use options; refresh and try again.';
    }
    final msg = e.message.trim();
    return msg.isNotEmpty ? msg : e.toString();
  }

  Future<CheckoutPricingRules> _loadPricingRules() async {
    try {
      final row = await client
          .from('store_settings')
          .select('delivery_fee_inr, free_delivery_above_inr')
          .eq('id', 1)
          .maybeSingle();
      return CheckoutPricingRules(
        deliveryFeeInr: (row?['delivery_fee_inr'] as num?)?.toDouble() ?? 49,
        freeDeliveryAboveInr:
            (row?['free_delivery_above_inr'] as num?)?.toDouble(),
      );
    } catch (_) {
      return CheckoutPricingRules.fallback;
    }
  }

  /// Per-product delivery modes for legacy fee preview (RPC is source of truth).
  Future<List<({String mode, double? customFeeInr})>>
      _loadDeliveryModesForItems(
    List<CartItem> items,
  ) async {
    final ids = items
        .map((e) => e.productId.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    try {
      final rows = await client
          .from('products')
          .select('id, delivery_charge_mode, delivery_charge_inr')
          .inFilter('id', ids);
      final byId = <String, ({String mode, double? customFeeInr})>{};
      for (final row in rows as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        byId[id] = (
          mode: (m['delivery_charge_mode'] ?? 'default').toString(),
          customFeeInr: (m['delivery_charge_inr'] as num?)?.toDouble(),
        );
      }
      return items
          .map(
            (e) => byId[e.productId] ?? (mode: 'default', customFeeInr: null),
          )
          .toList();
    } catch (_) {
      return items.map((_) => (mode: 'default', customFeeInr: null)).toList();
    }
  }

  Future<Map<String, dynamic>> _rpcPlaceOrder({
    required String orderCurrency,
    required List<Map<String, dynamic>> itemsPayload,
    required Map<String, dynamic> shippingPayload,
  }) async {
    try {
      return await client.rpc(
        'place_order_checkout',
        params: <String, dynamic>{
          'p_currency': orderCurrency,
          'p_items': itemsPayload,
          'p_shipping': shippingPayload,
        },
      ).then(_parseRpcOrderRow);
    } on PostgrestException catch (e) {
      if (_isRpcMissingPostgrest(e)) {
        rethrow;
      }
      final msg = e.message;
      final m = msg.toLowerCase();
      if (m.contains('insufficient_inventory')) {
        CheckoutTelemetry.inventoryInsufficient(hint: msg);
        throw const ValidationException(
            'Not enough stock for one or more items.');
      }
      if (m.contains('product_not_found')) {
        throw const ValidationException(
          'A product in your order is no longer available.',
        );
      }
      if (m.contains('not_authenticated')) {
        throw const AuthException('Sign in required to checkout.');
      }
      if (m.contains('empty_cart')) {
        throw const ValidationException('Your order has no items.');
      }
      if (m.contains('invalid_quantity')) {
        throw const ValidationException('Invalid quantity in your order.');
      }
      if (m.contains('shipping_required')) {
        throw const ValidationException('Shipping address is required.');
      }
      if (m.contains('invalid_shipping_phone')) {
        throw const ValidationException(
            'Enter a valid 10-digit mobile number.');
      }
      if (m.contains('invalid_shipping_postal')) {
        throw const ValidationException('Enter a valid 6-digit PIN code.');
      }
      if (m.contains('invalid_shipping')) {
        throw const ValidationException('Please check your shipping details.');
      }
      if (m.contains('product_not_available')) {
        CheckoutTelemetry.inactiveProductOrderAttempt(hint: msg);
        throw const ValidationException(
          'A product in your order is not available for purchase.',
        );
      }
      if (m.contains('currency_mismatch')) {
        throw const ValidationException(
          'Your cart mixes currencies; remove items and try again.',
        );
      }
      if (m.contains('invalid_product_id')) {
        throw const ValidationException('Invalid product in your order.');
      }
      if (m.contains('invalid_product_price')) {
        throw const ValidationException(
          'A product price could not be applied. Try again or contact support.',
        );
      }
      if (m.contains('product_tax_configuration_incomplete')) {
        throw const ValidationException(
          'A product tax configuration needs admin review before it can be purchased.',
        );
      }
      if (m.contains('variant_required')) {
        throw const ValidationException(
          'Please choose a product option for each item.',
        );
      }
      if (m.contains('variant_not_found') || m.contains('invalid_variant_id')) {
        throw const ValidationException(
          'A selected product option is no longer available.',
        );
      }
      if (m.contains('variant_not_applicable')) {
        throw const ValidationException(
          'This product does not use options; refresh and try again.',
        );
      }
      CheckoutTelemetry.checkoutRpcFailed(
        reason: 'unexpected_postgrest',
        detail: msg,
      );
      throw RepositoryException(_rpcUserMessage(e));
    }
  }

  Future<List<OrderItem>> _fetchOrderItemsFromDb(String orderId) async {
    final itemsData = await guard(
      () => client
          .from('order_items')
          .select(
            'id, order_id, product_id, variant_id, title, image_urls, unit_price, currency, quantity, hsn_code, tax_status, taxable_value, gst_rate, cgst_amount, sgst_amount, igst_amount, price_includes_gst',
          )
          .eq('order_id', orderId),
    );
    final list = (itemsData as List).cast<Map<String, dynamic>>();
    return list.map((e) => OrderItemModel.fromJson(e).toEntity()).toList();
  }

  /// Used when RPC [place_order_checkout] is not deployed. Stock is not decremented.
  Future<Map<String, dynamic>> _placeOrderLegacyInserts({
    required String userId,
    required String orderCurrency,
    required List<CartItem> checkoutItems,
    required ShippingDetails shipping,
    required double deliveryFee,
  }) async {
    final orderStatus = OrderStatus.pendingPayment.toDbValue();
    final insertedOrder = await guard(
      () => client
          .from('orders')
          .insert({
            'user_id': userId,
            'status': orderStatus,
            'currency': orderCurrency,
            'shipping_full_name': shipping.fullName.trim(),
            'shipping_phone': shipping.phone.trim(),
            'shipping_address_line': shipping.addressLine.trim(),
            'shipping_city': shipping.city.trim(),
            'shipping_postal_code': shipping.postalCode.trim(),
            'delivery_fee': deliveryFee,
          })
          .select('id, user_id, status, currency, created_at, delivery_fee')
          .single(),
    );
    final orderId = insertedOrder['id'].toString();
    for (final item in checkoutItems) {
      await guard(
        () => client.from('order_items').insert({
          'order_id': orderId,
          'product_id': item.productId,
          if (item.variantId != null) 'variant_id': item.variantId,
          'title': item.title,
          'image_urls': item.imageUrls,
          'unit_price': item.unitPrice,
          'currency': item.currency,
          'quantity': item.quantity,
        }),
      );
    }
    return Map<String, dynamic>.from(insertedOrder);
  }

  @override
  Future<Order> placeOrder({
    required ShippingDetails shipping,
    String? buyNowProductId,
    String? buyNowVariantId,
    int buyNowQuantity = 1,
  }) async {
    final v = shipping.validationError();
    if (v != null) {
      throw ValidationException(v);
    }

    final cart = await _cartRepository.getCart();

    late List<CartItem> checkoutItems;
    String? removeCartProductId;
    String? removeCartVariantId;
    var clearEntireCart = false;

    if (buyNowProductId == null) {
      if (cart.items.isEmpty) {
        throw const ValidationException('Cart is empty.');
      }
      checkoutItems = cart.items.toList();
      clearEntireCart = true;
    } else {
      var fromCart =
          cart.items.where((e) => e.productId == buyNowProductId).toList();
      final vFilter = buyNowVariantId?.trim();
      if (vFilter != null && vFilter.isNotEmpty) {
        fromCart = fromCart.where((e) => e.variantId == vFilter).toList();
      } else if (fromCart.length > 1) {
        fromCart = [fromCart.first];
      }
      if (fromCart.isNotEmpty) {
        checkoutItems = fromCart;
        removeCartProductId = buyNowProductId;
        removeCartVariantId =
            fromCart.length == 1 ? fromCart.first.variantId : vFilter;
      } else {
        late final Map<String, dynamic> productJson;
        try {
          final data = await guard(
            () => client
                .from('products')
                .select(
                  'id, title, price, currency, image_urls, inventory_count, available_stock, '
                  'product_variants(id, price, stock_quantity, available_stock, is_default, variant_name, image_url)',
                )
                .eq('id', buyNowProductId)
                .eq('is_active', true)
                .single(),
          );
          productJson = Map<String, dynamic>.from(data as Map);
        } catch (_) {
          final data = await guard(
            () => client
                .from('products')
                .select(
                  'id, title, price, currency, image_urls, inventory_count, available_stock',
                )
                .eq('id', buyNowProductId)
                .eq('is_active', true)
                .single(),
          );
          productJson = Map<String, dynamic>.from(data as Map);
        }
        final entity = ProductModel.fromJson(productJson).toEntity();
        final qty = buyNowQuantity < 1 ? 1 : buyNowQuantity;
        if (entity.hasVariants) {
          final want = buyNowVariantId?.trim();
          ProductVariant? chosen;
          if (want != null && want.isNotEmpty) {
            for (final v in entity.variants) {
              if (v.id == want) {
                chosen = v;
                break;
              }
            }
          }
          chosen ??= entity.defaultVariant;
          if (chosen == null) {
            throw const ValidationException(
                'No variant is available for this product.');
          }
          final inv = chosen.sellableStock;
          if (inv != null && inv <= 0) {
            throw const ValidationException('This product is out of stock.');
          }
          if (inv != null && qty > inv) {
            throw const ValidationException(
                'Requested quantity is not available.');
          }
          final vi = chosen.imageUrl.trim();
          final imgs = vi.isNotEmpty
              ? [vi, ...entity.imageUrls.where((u) => u != vi)]
              : entity.imageUrls;
          checkoutItems = [
            CartItem(
              productId: entity.id,
              variantId: chosen.id,
              variantName: chosen.variantName,
              title:
                  '${entity.title} · ${chosen.variantType.trim().isNotEmpty ? '${chosen.variantType}: ' : ''}${chosen.variantName}',
              imageUrls: imgs,
              unitPrice: chosen.price,
              currency: entity.currency,
              quantity: qty,
            ),
          ];
        } else {
          final product = ProductModel.fromJson(productJson);
          final inv = product.sellableQuantity;
          if (inv != null && inv <= 0) {
            throw const ValidationException('This product is out of stock.');
          }
          if (inv != null && qty > inv) {
            throw const ValidationException(
                'Requested quantity is not available.');
          }
          checkoutItems = [
            CartItem(
              productId: product.id,
              title: product.title,
              imageUrls: product.imageUrls,
              unitPrice: product.price,
              currency: product.currency,
              quantity: qty,
            ),
          ];
        }
      }
    }

    checkoutItems = _mergeLinesByProductAndVariant(checkoutItems);

    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required to checkout.');
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );

    final orderCurrency = checkoutItems.first.currency;
    final subtotal = checkoutItems.fold<double>(0, (s, e) => s + e.lineTotal);
    final pricing = await _loadPricingRules();
    final deliveryModes = await _loadDeliveryModesForItems(checkoutItems);
    final legacyDelivery = pricing.deliveryForCart(
      subtotal: subtotal,
      productModes: deliveryModes,
    );

    final itemsPayload = checkoutItems
        .map(
          (e) => <String, dynamic>{
            'product_id': e.productId,
            if (e.variantId != null && e.variantId!.trim().isNotEmpty)
              'variant_id': e.variantId,
            'title': e.title,
            'image_urls': e.imageUrls,
            'unit_price': e.unitPrice,
            'currency': e.currency,
            'quantity': e.quantity,
          },
        )
        .toList();

    final shippingPayload = shipping.toRpcJson();

    Map<String, dynamic> orderRow;
    var checkoutUsedRpc = false;
    try {
      orderRow = await _rpcPlaceOrder(
        orderCurrency: orderCurrency,
        itemsPayload: itemsPayload,
        shippingPayload: shippingPayload,
      );
      checkoutUsedRpc = true;
    } on PostgrestException catch (e) {
      if (!_isRpcMissingPostgrest(e)) {
        rethrow;
      }
      CheckoutTelemetry.checkoutRpcFailed(
        reason: 'rpc_not_available',
        detail: e.message,
      );
      if (!_legacyCheckoutFallbackEnabled) {
        throw const RepositoryException(
          'Checkout is temporarily unavailable. Please try again in a few minutes.',
        );
      }
      CheckoutTelemetry.legacyCheckoutAttempt(reason: 'rpc_missing_fallback');
      orderRow = await _placeOrderLegacyInserts(
        userId: authUser.id,
        orderCurrency: orderCurrency,
        checkoutItems: checkoutItems,
        shipping: shipping,
        deliveryFee: legacyDelivery,
      );
    } catch (e) {
      if (_isMissingCheckoutRpcError(e)) {
        CheckoutTelemetry.checkoutRpcFailed(
          reason: 'rpc_not_available',
          detail: e.toString(),
        );
        if (!_legacyCheckoutFallbackEnabled) {
          throw const RepositoryException(
            'Checkout is temporarily unavailable. Please try again in a few minutes.',
          );
        }
        CheckoutTelemetry.legacyCheckoutAttempt(
          reason: 'rpc_missing_fallback_non_postgrest',
        );
        orderRow = await _placeOrderLegacyInserts(
          userId: authUser.id,
          orderCurrency: orderCurrency,
          checkoutItems: checkoutItems,
          shipping: shipping,
          deliveryFee: legacyDelivery,
        );
      } else {
        rethrow;
      }
    }

    // RPC uses checkout_* keys (PL/pgSQL RETURN TABLE names must not collide with table columns).
    final idRaw =
        orderRow['checkout_order_id'] ?? orderRow['order_id'] ?? orderRow['id'];
    if (idRaw == null) {
      throw const RepositoryException('Checkout response missing order id.');
    }
    final orderId = idRaw.toString();
    if (shipping.state?.trim().isNotEmpty == true) {
      await client.rpc(
        'set_order_shipping_state',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_shipping_state': shipping.state!.trim(),
        },
      );
    }
    final statusDb = (orderRow['checkout_status'] ??
                orderRow['order_status'] ??
                orderRow['status'])
            ?.toString() ??
        OrderStatus.pendingPayment.toDbValue();
    final createdAtStr = (orderRow['checkout_created_at'] ??
            orderRow['order_created_at'] ??
            orderRow['created_at'])
        ?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    final deliveryFeeRaw =
        orderRow['checkout_delivery_fee'] ?? orderRow['delivery_fee'];
    final deliveryFee = (deliveryFeeRaw as num?)?.toDouble() ?? legacyDelivery;

    final List<OrderItem> orderItems;
    if (checkoutUsedRpc) {
      orderItems = await _fetchOrderItemsFromDb(orderId);
    } else {
      orderItems = checkoutItems
          .map(
            (e) => OrderItem(
              variantId: e.variantId,
              productId: e.productId,
              title: e.title,
              imageUrls: e.imageUrls,
              unitPrice: e.unitPrice,
              currency: e.currency,
              quantity: e.quantity,
            ),
          )
          .toList();
    }

    if (clearEntireCart) {
      await _cartRepository.clearCart();
    } else if (removeCartProductId != null) {
      await _cartRepository.removeItem(
        productId: removeCartProductId,
        variantId: removeCartVariantId,
      );
    }

    return Order(
      id: orderId,
      userId: authUser.id,
      status: OrderStatusX.fromDbValue(statusDb),
      items: orderItems,
      currency: orderCurrency,
      createdAt: createdAt,
      deliveryFee: deliveryFee,
      paymentMethod: OrderPaymentMethod.razorpay,
      paymentStatus: OrderPaymentStatus.pending,
      returnDeadline: null,
    );
  }
}
