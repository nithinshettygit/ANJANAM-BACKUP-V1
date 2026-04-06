import 'dart:typed_data';

import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/search/order_search_utils.dart';
import 'package:ecommerce_app/core/formatting/estimated_delivery_format.dart';
import '../utils/admin_order_status_workflow.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, PostgrestException, SupabaseClient;

class AdminDashboardSummary {
  final int totalProducts;
  final int totalOrders;
  final int totalUsers;
  final double totalRevenue;
  final List<AdminOrderRow> recentOrders;
  final int totalArticles;
  final int freeArticles;
  final int premiumArticles;
  final int articleSales;
  final double articleRevenue;

  const AdminDashboardSummary({
    required this.totalProducts,
    required this.totalOrders,
    required this.totalUsers,
    required this.totalRevenue,
    required this.recentOrders,
    this.totalArticles = 0,
    this.freeArticles = 0,
    this.premiumArticles = 0,
    this.articleSales = 0,
    this.articleRevenue = 0,
  });
}

class DailyMetricPoint {
  final DateTime date;
  final double value;

  const DailyMetricPoint({
    required this.date,
    required this.value,
  });
}

class TopSellingProduct {
  final String productId;
  final String title;
  final int quantitySold;
  final double revenue;

  const TopSellingProduct({
    required this.productId,
    required this.title,
    required this.quantitySold,
    required this.revenue,
  });
}

class AdminDashboardAnalytics {
  final double revenueToday;
  final double revenueThisMonth;
  final int totalOrders;
  final int pendingOrders;
  final int totalCustomers;
  final double averageOrderValue;
  final List<DailyMetricPoint> revenueTrend;
  final List<DailyMetricPoint> ordersPerDay;
  final List<TopSellingProduct> topSellingProducts;

  const AdminDashboardAnalytics({
    required this.revenueToday,
    required this.revenueThisMonth,
    required this.totalOrders,
    required this.pendingOrders,
    required this.totalCustomers,
    required this.averageOrderValue,
    required this.revenueTrend,
    required this.ordersPerDay,
    required this.topSellingProducts,
  });
}

class AdminProduct {
  final String id;
  final String title;
  final String description;
  final String? category;
  final String sku;
  final String brand;
  final List<String> tags;
  final double price;
  final String currency;
  final double weight;
  final String dimensions;
  final int inventoryCount;
  final List<String> imageUrls;
  final DateTime? createdAt;
  final bool isActive;
  final int displayDiscountPercent;
  final bool isPopular;
  final bool isRecommended;
  final bool isFestivalSpecial;

  const AdminProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.sku,
    required this.brand,
    required this.tags,
    required this.price,
    required this.currency,
    required this.weight,
    required this.dimensions,
    required this.inventoryCount,
    required this.imageUrls,
    required this.createdAt,
    required this.isActive,
    this.displayDiscountPercent = 0,
    this.isPopular = false,
    this.isRecommended = false,
    this.isFestivalSpecial = false,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    bool readBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    final images = json['image_urls'];
    final dd = json['display_discount_percent'];
    final discount = dd is int
        ? dd.clamp(0, 99)
        : dd is num
            ? dd.round().clamp(0, 99)
            : 0;
    return AdminProduct(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: json['category']?.toString(),
      sku: (json['sku'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: currencyOrInr(json['currency']),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      dimensions: (json['dimensions'] ?? '').toString(),
      inventoryCount: (json['inventory_count'] as num?)?.toInt() ?? 0,
      imageUrls: images is List ? images.map((e) => e.toString()).toList() : const [],
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      isActive: json['is_active'] == null ? true : readBool(json['is_active']),
      displayDiscountPercent: discount,
      isPopular: readBool(json['is_popular']),
      isRecommended: readBool(json['is_recommended']),
      isFestivalSpecial: readBool(json['is_festival_special']),
    );
  }
}

class AdminSearchResultItem {
  final String type;
  final String id;
  final String title;
  final String subtitle;

  const AdminSearchResultItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

class AdminOrderRow {
  final String id;
  final String userId;
  final String customerName;
  final String customerEmail;
  final String status;
  final String currency;
  final DateTime createdAt;

  /// Sum of line items (excludes delivery).
  final double itemsSubtotal;

  /// Delivery fee charged on this order.
  final double deliveryFee;

  /// Payable total: [itemsSubtotal] + [deliveryFee].
  final double totalAmount;

  /// `razorpay` or `cod` from `orders.payment_method`.
  final String paymentMethod;

  /// `paid`, `pending`, or `failed` from `orders.payment_status`.
  final String paymentStatus;

  final String? razorpayPaymentId;

  const AdminOrderRow({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.customerEmail,
    required this.status,
    required this.currency,
    required this.createdAt,
    required this.itemsSubtotal,
    required this.deliveryFee,
    required this.totalAmount,
    this.paymentMethod = 'razorpay',
    this.paymentStatus = 'pending',
    this.razorpayPaymentId,
  });
}

class AdminOrderItemRow {
  final String? orderItemId;
  final String productId;
  final String title;
  final int quantity;
  final double unitPrice;
  final String currency;
  final List<String> imageUrls;

  const AdminOrderItemRow({
    this.orderItemId,
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.currency,
    required this.imageUrls,
  });
}

class AdminOrderTimelineEvent {
  final String label;
  final DateTime timestamp;
  final String? notes;

  const AdminOrderTimelineEvent({
    required this.label,
    required this.timestamp,
    this.notes,
  });
}

class AdminOrderDetails {
  final AdminOrderRow order;
  final List<AdminOrderItemRow> items;
  /// Legacy single-line field; prefer structured shipping when present.
  final String shippingAddress;
  final String? shippingFullName;
  final String? shippingPhone;
  final String? shippingAddressLine;
  final String? shippingCity;
  final String? shippingPostalCode;
  /// Display: Razorpay or COD.
  final String paymentMethod;
  final String paymentStatus;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final List<AdminOrderTimelineEvent> timeline;
  final String? trackingNumber;
  final String? courierName;
  final DateTime? estimatedDeliveryDate;
  final double? packageWeightKg;
  final String? packageDimensionsCm;

  const AdminOrderDetails({
    required this.order,
    required this.items,
    required this.shippingAddress,
    this.shippingFullName,
    this.shippingPhone,
    this.shippingAddressLine,
    this.shippingCity,
    this.shippingPostalCode,
    required this.paymentMethod,
    required this.paymentStatus,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    required this.timeline,
    this.trackingNumber,
    this.courierName,
    this.estimatedDeliveryDate,
    this.packageWeightKg,
    this.packageDimensionsCm,
  });
}

class AdminReturnRow {
  final String id;
  final String orderId;
  final String userId;
  final String customerName;
  final String productId;
  final String orderItemId;
  final String returnReason;
  final String returnType;
  final String returnStatus;
  final DateTime createdAt;
  final List<String> returnImages;
  final String? returnNote;
  final DateTime? pickupScheduledAt;
  final String? pickupNotes;
  final String? rejectionReason;
  final String lineTitle;
  final double lineAmount;
  final String? refundId;
  final String? refundStatus;
  final double? refundAmount;
  final String? refundMethod;
  final String? paymentTransactionId;
  final String? orderPaymentTransactionId;
  final String? replacementOrderId;
  final String? pickupCourierPartner;
  final DateTime? warehouseReceiptAt;
  final String? inspectionNotes;
  final String? razorpayRefundId;
  final String? gatewayRefundStatus;

  const AdminReturnRow({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.customerName,
    required this.productId,
    required this.orderItemId,
    required this.returnReason,
    required this.returnType,
    required this.returnStatus,
    required this.createdAt,
    required this.returnImages,
    required this.returnNote,
    required this.pickupScheduledAt,
    required this.pickupNotes,
    required this.rejectionReason,
    required this.lineTitle,
    required this.lineAmount,
    required this.refundId,
    required this.refundStatus,
    required this.refundAmount,
    required this.refundMethod,
    required this.paymentTransactionId,
    required this.orderPaymentTransactionId,
    this.replacementOrderId,
    this.pickupCourierPartner,
    this.warehouseReceiptAt,
    this.inspectionNotes,
    this.razorpayRefundId,
    this.gatewayRefundStatus,
  });
}

class AdminUserRow {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final int totalOrders;
  final double totalSpent;
  final DateTime? createdAt;
  final String status;
  final String? blockedReason;
  final DateTime? blockedAt;

  const AdminUserRow({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.totalOrders,
    required this.totalSpent,
    required this.createdAt,
    required this.status,
    this.blockedReason,
    this.blockedAt,
  });
}

class AdminUserDetails {
  final AdminUserRow user;
  final List<AdminOrderRow> orders;
  final String phone;
  final String address;
  final DateTime? firstOrderDate;
  final DateTime? lastOrderDate;
  final double averageOrderValue;
  final double totalRevenue;

  const AdminUserDetails({
    required this.user,
    required this.orders,
    required this.phone,
    required this.address,
    required this.firstOrderDate,
    required this.lastOrderDate,
    required this.averageOrderValue,
    required this.totalRevenue,
  });
}

class ProductUpsertInput {
  final String title;
  final String description;
  final String category;
  final String sku;
  final String brand;
  final List<String> tags;
  final double price;
  final String currency;
  final double weight;
  final String dimensions;
  final int inventoryCount;
  final List<String> imageUrls;
  final int displayDiscountPercent;
  final bool isPopular;
  final bool isRecommended;
  final bool isFestivalSpecial;

  const ProductUpsertInput({
    required this.title,
    required this.description,
    required this.category,
    required this.sku,
    required this.brand,
    required this.tags,
    required this.price,
    required this.currency,
    required this.weight,
    required this.dimensions,
    required this.inventoryCount,
    required this.imageUrls,
    this.displayDiscountPercent = 0,
    this.isPopular = false,
    this.isRecommended = false,
    this.isFestivalSpecial = false,
  });
}

class AdminHomeHeroBannerRow {
  final String id;
  final String imageUrl;
  final String redirectType;
  final String redirectValue;
  final int sortOrder;
  final bool enabled;

  const AdminHomeHeroBannerRow({
    required this.id,
    required this.imageUrl,
    required this.redirectType,
    required this.redirectValue,
    required this.sortOrder,
    required this.enabled,
  });

  factory AdminHomeHeroBannerRow.fromJson(Map<String, dynamic> json) {
    return AdminHomeHeroBannerRow(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      redirectType: (json['redirect_type'] ?? 'category').toString(),
      redirectValue: (json['redirect_value'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}

class AdminHomeTopCategoryRow {
  final String id;
  final String label;
  final String iconUrl;
  final String categorySlug;
  final int sortOrder;
  final bool enabled;

  const AdminHomeTopCategoryRow({
    required this.id,
    required this.label,
    required this.iconUrl,
    required this.categorySlug,
    required this.sortOrder,
    required this.enabled,
  });

  factory AdminHomeTopCategoryRow.fromJson(Map<String, dynamic> json) {
    return AdminHomeTopCategoryRow(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      iconUrl: (json['icon_url'] ?? '').toString(),
      categorySlug: (json['category_slug'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}

class AdminCategoryOption {
  final String slug;
  final String label;

  const AdminCategoryOption({
    required this.slug,
    required this.label,
  });
}

class AdminCatalogCategoryRow {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final bool isActive;
  final bool showInShop;
  final int displayOrder;

  const AdminCatalogCategoryRow({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    required this.isActive,
    required this.showInShop,
    required this.displayOrder,
  });

  factory AdminCatalogCategoryRow.fromJson(Map<String, dynamic> json) {
    return AdminCatalogCategoryRow(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      isActive: (json['is_active'] as bool?) ?? true,
      showInShop: (json['show_in_shop'] as bool?) ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Single-row checkout delivery rules from [store_settings] (id = 1).
class AdminStoreDeliverySettings {
  final double deliveryFeeInr;
  final double? freeDeliveryAboveInr;
  final DateTime? updatedAt;

  const AdminStoreDeliverySettings({
    required this.deliveryFeeInr,
    this.freeDeliveryAboveInr,
    this.updatedAt,
  });
}

class AdminService {
  final SupabaseClient client;

  const AdminService(this.client);

  Future<void> _requireAdmin() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please login to access admin features.');
    }
    final allowed = await isCurrentUserAdmin();
    if (!allowed) {
      throw const AuthException('Admin role required.');
    }
  }

  // Standardized service API for admin module.
  Future<AdminDashboardSummary> getDashboardStats() => fetchDashboardSummary();
  Future<List<AdminProduct>> getProducts() => fetchProducts();
  Future<List<AdminOrderRow>> getOrders({int? limit, String? searchQuery}) =>
      fetchOrders(limit: limit, searchQuery: searchQuery);
  Future<List<AdminUserRow>> getUsers() => fetchUsers();
  Future<void> blockUser(String userId, {String? reason}) =>
      setUserBlocked(userId, blocked: true, reason: reason);
  Future<void> unblockUser(String userId) =>
      setUserBlocked(userId, blocked: false);
  Future<void> promoteToAdmin(String userId) =>
      setUserRole(userId, role: 'admin');
  Future<void> removeAdmin(String userId) =>
      setUserRole(userId, role: 'customer');
  Future<List<AdminProduct>> getInventory() => fetchProducts();

  Future<bool> isCurrentUserAdmin() async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    try {
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role']?.toString().toLowerCase().trim();
      return role == 'admin' || role == 'super_admin';
    } catch (_) {
      // Any lookup failure should be treated as non-admin access.
      return false;
    }
  }

  Future<bool> isCurrentUserSuperAdmin() async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    try {
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role']?.toString().toLowerCase().trim();
      return role == 'super_admin';
    } catch (_) {
      return false;
    }
  }

  Future<AdminDashboardSummary> fetchDashboardSummary() async {
    await _requireAdmin();
    final products = await client.from('products').select('id');
    final orders = await client.from('orders').select('id, status, currency, created_at, user_id');
    final users = await client.from('profiles').select('id');

    final recentOrders = await fetchOrders(limit: 10);
    final allOrderIds = (orders as List)
        .map((e) => (e as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final revenue = await _fetchRevenueForOrderIds(allOrderIds);
    final articlesData = await client.from('articles').select('id, is_free, price');
    final purchasesData = await client.from('article_purchases').select('id, article_id');
    final articleRows = (articlesData as List).cast<Map<String, dynamic>>();
    final purchaseRows = (purchasesData as List).cast<Map<String, dynamic>>();
    final articleById = <String, Map<String, dynamic>>{
      for (final row in articleRows) (row['id'] ?? '').toString(): row,
    };
    var articleRevenue = 0.0;
    for (final row in purchaseRows) {
      final articleId = (row['article_id'] ?? '').toString();
      final article = articleById[articleId];
      if (article == null) continue;
      articleRevenue += (article['price'] as num?)?.toDouble() ?? 0;
    }
    final freeArticles = articleRows.where((e) => e['is_free'] == true).length;
    final premiumArticles = articleRows.length - freeArticles;

    return AdminDashboardSummary(
      totalProducts: (products as List).length,
      totalOrders: (orders).length,
      totalUsers: (users as List).length,
      totalRevenue: revenue,
      recentOrders: recentOrders,
      totalArticles: articleRows.length,
      freeArticles: freeArticles,
      premiumArticles: premiumArticles,
      articleSales: purchaseRows.length,
      articleRevenue: articleRevenue,
    );
  }

  Future<AdminDashboardAnalytics> fetchDashboardAnalytics({int days = 7}) async {
    await _requireAdmin();
    final normalizedDays = days <= 0 ? 7 : days;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: normalizedDays - 1));

    final ordersData = await client
        .from('orders')
        .select('id, user_id, status, created_at, delivery_fee');
    final orders = (ordersData as List).cast<Map<String, dynamic>>();
    final orderIds = orders
        .map((o) => o['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final orderItemsData = orderIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client
            .from('order_items')
            .select('order_id, product_id, title, quantity, unit_price')
            .inFilter('order_id', orderIds) as List<dynamic>;
    final orderItems = orderItemsData.cast<Map<String, dynamic>>();

    final totalsByOrder = <String, double>{};
    for (final item in orderItems) {
      final orderId = (item['order_id'] ?? '').toString();
      if (orderId.isEmpty) continue;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
      totalsByOrder[orderId] = (totalsByOrder[orderId] ?? 0) + (quantity * unitPrice);
    }

    double revenueToday = 0;
    double revenueThisMonth = 0;
    int pendingOrders = 0;
    final customerIds = <String>{};
    final revenueByDate = <DateTime, double>{};
    final orderCountByDate = <DateTime, int>{};

    for (final order in orders) {
      final orderId = (order['id'] ?? '').toString();
      final userId = (order['user_id'] ?? '').toString();
      if (userId.isNotEmpty) customerIds.add(userId);
      final status = (order['status'] ?? '').toString().toLowerCase().trim();
      if (const {
            'pending_payment',
            'placed',
            'processing',
            'packed',
            'shipped',
            'out_for_delivery',
          }.contains(status)) {
        pendingOrders += 1;
      }

      final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      final orderDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final itemsTotal = totalsByOrder[orderId] ?? 0;
      final delivery = _deliveryFeeFromRow(order);
      final total = itemsTotal + delivery;

      if (createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day) {
        revenueToday += total;
      }
      if (createdAt.year == now.year && createdAt.month == now.month) {
        revenueThisMonth += total;
      }
      if (!orderDate.isBefore(startDate) && !orderDate.isAfter(DateTime(now.year, now.month, now.day))) {
        revenueByDate[orderDate] = (revenueByDate[orderDate] ?? 0) + total;
        orderCountByDate[orderDate] = (orderCountByDate[orderDate] ?? 0) + 1;
      }
    }

    final productAgg = <String, TopSellingProduct>{};
    for (final item in orderItems) {
      final productId = (item['product_id'] ?? '').toString();
      final titleRaw = (item['title'] ?? '').toString().trim();
      final title = titleRaw.isEmpty ? 'Product ${productId.isEmpty ? '-' : productId}' : titleRaw;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
      final key = productId.isEmpty ? title : productId;
      final existing = productAgg[key];
      if (existing == null) {
        productAgg[key] = TopSellingProduct(
          productId: productId,
          title: title,
          quantitySold: quantity,
          revenue: quantity * unitPrice,
        );
      } else {
        productAgg[key] = TopSellingProduct(
          productId: existing.productId,
          title: existing.title,
          quantitySold: existing.quantitySold + quantity,
          revenue: existing.revenue + (quantity * unitPrice),
        );
      }
    }

    final revenueTrend = <DailyMetricPoint>[];
    final ordersPerDay = <DailyMetricPoint>[];
    for (var i = 0; i < normalizedDays; i++) {
      final d = startDate.add(Duration(days: i));
      final key = DateTime(d.year, d.month, d.day);
      revenueTrend.add(DailyMetricPoint(date: key, value: revenueByDate[key] ?? 0));
      ordersPerDay.add(
        DailyMetricPoint(date: key, value: (orderCountByDate[key] ?? 0).toDouble()),
      );
    }

    final topProducts = productAgg.values.toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    var totalRevenue = 0.0;
    for (final o in orders) {
      final oid = (o['id'] ?? '').toString();
      if (oid.isEmpty) continue;
      totalRevenue += (totalsByOrder[oid] ?? 0) + _deliveryFeeFromRow(o);
    }
    final totalOrders = orders.length;
    final avgOrderValue = totalOrders == 0 ? 0.0 : totalRevenue / totalOrders;

    return AdminDashboardAnalytics(
      revenueToday: revenueToday,
      revenueThisMonth: revenueThisMonth,
      totalOrders: totalOrders,
      pendingOrders: pendingOrders,
      totalCustomers: customerIds.length,
      averageOrderValue: avgOrderValue,
      revenueTrend: revenueTrend,
      ordersPerDay: ordersPerDay,
      topSellingProducts: topProducts.take(5).toList(),
    );
  }

  Future<AdminStoreDeliverySettings> fetchStoreDeliverySettings() async {
    await _requireAdmin();
    try {
      final row = await client
          .from('store_settings')
          .select('delivery_fee_inr, free_delivery_above_inr, updated_at')
          .eq('id', 1)
          .maybeSingle();
      return AdminStoreDeliverySettings(
        deliveryFeeInr: (row?['delivery_fee_inr'] as num?)?.toDouble() ?? 49,
        freeDeliveryAboveInr: (row?['free_delivery_above_inr'] as num?)?.toDouble(),
        updatedAt: () {
          final ts = row?['updated_at'];
          if (ts == null) return null;
          return DateTime.tryParse(ts.toString());
        }(),
      );
    } catch (_) {
      try {
        final row = await client
            .from('store_settings')
            .select('delivery_fee_inr, free_delivery_above_inr')
            .eq('id', 1)
            .maybeSingle();
        return AdminStoreDeliverySettings(
          deliveryFeeInr: (row?['delivery_fee_inr'] as num?)?.toDouble() ?? 49,
          freeDeliveryAboveInr: (row?['free_delivery_above_inr'] as num?)?.toDouble(),
        );
      } catch (_) {
        return const AdminStoreDeliverySettings(deliveryFeeInr: 49, freeDeliveryAboveInr: 500);
      }
    }
  }

  Future<void> updateStoreDeliverySettings({
    required double deliveryFeeInr,
    double? freeDeliveryAboveInr,
  }) async {
    await _requireAdmin();
    if (deliveryFeeInr < 0) {
      throw ArgumentError('deliveryFeeInr must be >= 0');
    }
    if (freeDeliveryAboveInr != null && freeDeliveryAboveInr < 0) {
      throw ArgumentError('freeDeliveryAboveInr must be >= 0 or null');
    }
    await client.from('store_settings').update({
      'delivery_fee_inr': deliveryFeeInr,
      'free_delivery_above_inr': freeDeliveryAboveInr,
    }).eq('id', 1);
    await _logAdminAction(
      action: 'store_delivery_updated',
      entity: 'store_settings',
      entityId: '1',
      message:
          'Admin set delivery fee ₹${deliveryFeeInr.toStringAsFixed(2)}, free delivery above '
          '${freeDeliveryAboveInr == null ? '—' : '₹${freeDeliveryAboveInr.toStringAsFixed(2)}'}',
    );
  }

  Future<List<AdminProduct>> fetchProducts() async {
    await _requireAdmin();
    dynamic data;
    try {
      data = await client
          .from('products')
          .select(
              'id, title, description, category, sku, brand, tags, price, currency, weight, dimensions, inventory_count, image_urls, created_at, is_active, display_discount_percent, is_popular, is_recommended, is_festival_special')
          .eq('is_active', true)
          .order('created_at', ascending: false);
    } catch (_) {
      data = await client
          .from('products')
          .select(
              'id, title, description, category, price, currency, inventory_count, image_urls, created_at, is_active, is_popular, is_recommended, is_festival_special')
          .order('created_at', ascending: false);
    }
    return (data as List).cast<Map<String, dynamic>>().map((json) {
      final product = AdminProduct.fromJson(json);
      return _normalizeProductImages(product);
    }).toList();
  }

  Future<void> createProduct(ProductUpsertInput input, {String? explicitId}) async {
    await _requireAdmin();
    final row = <String, dynamic>{
      if (explicitId != null && explicitId.isNotEmpty) 'id': explicitId,
      'title': input.title,
      'description': input.description,
      'category': input.category,
      'sku': input.sku,
      'brand': input.brand,
      'tags': input.tags,
      'price': input.price,
      'currency': input.currency,
      'weight': input.weight,
      'dimensions': input.dimensions,
      'inventory_count': input.inventoryCount,
      'image_urls': input.imageUrls,
      'display_discount_percent': input.displayDiscountPercent.clamp(0, 99),
      'is_popular': input.isPopular,
      'is_recommended': input.isRecommended,
      'is_festival_special': input.isFestivalSpecial,
    };
    final created = await client.from('products').insert(row).select('id').single();
    final productId = (created['id'] ?? '').toString();
    await _logAdminAction(
      action: 'product_created',
      entity: 'product',
      entityId: productId,
      message: 'Admin created product "${input.title}" ($productId)',
    );
  }

  Future<void> updateProduct(String productId, ProductUpsertInput input) async {
    await _requireAdmin();
    Map<String, dynamic>? before;
    try {
      before = await client
          .from('products')
          .select('title, price, currency')
          .eq('id', productId)
          .single();
    } catch (_) {
      before = null;
    }
    await client.from('products').update({
      'title': input.title,
      'description': input.description,
      'category': input.category,
      'sku': input.sku,
      'brand': input.brand,
      'tags': input.tags,
      'price': input.price,
      'currency': input.currency,
      'weight': input.weight,
      'dimensions': input.dimensions,
      'inventory_count': input.inventoryCount,
      'image_urls': input.imageUrls,
      'display_discount_percent': input.displayDiscountPercent.clamp(0, 99),
      'is_popular': input.isPopular,
      'is_recommended': input.isRecommended,
      'is_festival_special': input.isFestivalSpecial,
    }).eq('id', productId);

    final title = (before?['title'] ?? input.title).toString();
    final oldPrice = (before?['price'] as num?)?.toDouble();
    final cur = currencyOrInr(before?['currency'] ?? input.currency);
    String message;
    if (oldPrice != null && (oldPrice - input.price).abs() > 0.001) {
      message =
          'Admin updated product price: "$title" ${oldPrice.toStringAsFixed(2)} → ${input.price.toStringAsFixed(2)} $cur ($productId)';
    } else {
      message = 'Admin updated product "$title" ($productId)';
    }
    await _logAdminAction(
      action: 'product_updated',
      entity: 'product',
      entityId: productId,
      message: message,
    );
  }

  Future<void> deleteProduct(String productId) async {
    await _requireAdmin();
    var title = productId;
    try {
      final row = await client.from('products').select('title').eq('id', productId).single();
      title = (row['title'] ?? productId).toString();
    } catch (_) {}
    try {
      final outcome = await client.rpc(
        'admin_delete_product_safe',
        params: <String, dynamic>{'p_product_id': productId},
      );
      final normalized = (outcome ?? '').toString().toLowerCase().trim();
      if (normalized == 'archived') {
        await _logAdminAction(
          action: 'product_archived',
          entity: 'product',
          entityId: productId,
          message:
              'Admin archived product "$title" ($productId) because hard delete was blocked by references',
        );
        return;
      }
      await _logAdminAction(
        action: 'product_deleted',
        entity: 'product',
        entityId: productId,
        message: 'Admin deleted product "$title" ($productId)',
      );
      return;
    } on PostgrestException catch (_) {
      // Fallback for environments where migration 041 is not yet applied.
    }
    try {
      await client.from('products').delete().eq('id', productId);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final details = e.details?.toString().toLowerCase() ?? '';
      final code = e.code?.toLowerCase() ?? '';
      // Keep admin flow usable when hard-delete is blocked by FK references
      // (orders/cart/wishlist/returns etc). We archive instead.
      final likelyFkBlock = code == '23503' ||
          msg.contains('foreign key') ||
          details.contains('foreign key') ||
          msg.contains('violates') ||
          details.contains('violates') ||
          msg.contains('constraint') ||
          details.contains('constraint');
      if (!likelyFkBlock) rethrow;
      try {
        await client.from('products').update({
          'is_active': false,
          'inventory_count': 0,
        }).eq('id', productId);
      } on PostgrestException catch (archiveError) {
        final archMsg = archiveError.message.toLowerCase();
        final missingIsActive = archMsg.contains('is_active') &&
            (archMsg.contains('column') || archMsg.contains('does not exist'));
        if (!missingIsActive) rethrow;
        // Older DB schema fallback: disable stock only when `is_active` does not exist.
        await client.from('products').update({
          'inventory_count': 0,
        }).eq('id', productId);
      }
      await _logAdminAction(
        action: 'product_archived',
        entity: 'product',
        entityId: productId,
        message:
            'Admin archived product "$title" ($productId) because hard delete was blocked by references',
      );
      return;
    }
    await _logAdminAction(
      action: 'product_deleted',
      entity: 'product',
      entityId: productId,
      message: 'Admin deleted product "$title" ($productId)',
    );
  }

  Future<bool> updateProductActive({
    required String productId,
    required bool isActive,
  }) async {
    try {
      await _requireAdmin();
      await client.from('products').update({'is_active': isActive}).eq('id', productId);
      await _logAdminAction(
        action: 'product_active_toggled',
        entity: 'product',
        entityId: productId,
        message: 'Admin set product $productId active=${isActive ? 'true' : 'false'}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateInventory({
    required String productId,
    required int inventoryCount,
  }) async {
    await _requireAdmin();
    var title = productId;
    int? oldCount;
    try {
      final row = await client
          .from('products')
          .select('title, inventory_count')
          .eq('id', productId)
          .single();
      title = (row['title'] ?? productId).toString();
      oldCount = (row['inventory_count'] as num?)?.toInt();
    } catch (_) {}
    await client
        .from('products')
        .update({'inventory_count': inventoryCount}).eq('id', productId);
    await _logAdminAction(
      action: 'inventory_updated',
      entity: 'product',
      entityId: productId,
      message:
          'Admin updated inventory: "$title" ${oldCount ?? '?'} → $inventoryCount ($productId)',
    );
  }

  Future<List<AdminOrderRow>> fetchOrders({int? limit, String? searchQuery}) async {
    await _requireAdmin();
    List<Map<String, dynamic>> orders;
    try {
      dynamic query = client
          .from('orders')
          .select(
            'id, user_id, status, currency, created_at, delivery_fee, customer_email, '
            'payment_method, payment_status, razorpay_payment_id',
          )
          .order('created_at', ascending: false);
      if (limit != null) {
        query = query.limit(limit);
      }
      orders = (await query as List).cast<Map<String, dynamic>>();
    } catch (_) {
      dynamic query = client
          .from('orders')
          .select(
            'id, user_id, status, currency, created_at, delivery_fee, '
            'payment_method, payment_status, razorpay_payment_id',
          )
          .order('created_at', ascending: false);
      if (limit != null) {
        query = query.limit(limit);
      }
      orders = (await query as List).cast<Map<String, dynamic>>();
    }

    if (orders.isEmpty) return const [];

    final userIds = orders
        .map((e) => e['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final orderIds = orders
        .map((e) => e['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    List<Map<String, dynamic>> profilesData;
    if (userIds.isEmpty) {
      profilesData = const [];
    } else {
      try {
        profilesData = (await client
                .from('profiles')
                .select('id, full_name, email')
                .inFilter('id', userIds) as List)
            .cast<Map<String, dynamic>>();
      } catch (_) {
        profilesData = (await client
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', userIds) as List)
            .cast<Map<String, dynamic>>();
      }
    }
    final profiles = {
      for (final p in profilesData) p['id'].toString(): p
    };
    final emailsByUserId = await _fetchAuthEmailsByUserIds(userIds);

    final totalsByOrder = await _fetchOrderTotals(orderIds);

    final rows = orders.map((row) {
      final userId = row['user_id']?.toString() ?? '';
      final profile = profiles[userId];
      final oid = row['id'].toString();
      final subtotal = totalsByOrder[oid] ?? 0;
      final delivery = _deliveryFeeFromRow(row);
      final pm = _orderPaymentMethodRaw(row);
      return AdminOrderRow(
        id: oid,
        userId: userId,
        customerName: profile?['full_name']?.toString().trim().isNotEmpty == true
            ? profile!['full_name'].toString()
            : 'User',
        customerEmail: _customerEmailForOrder(
          orderSnapshotEmail: row['customer_email'],
          profileEmail: profile?['email']?.toString(),
          authMapEmail: emailsByUserId[userId],
        ),
        status: (row['status'] ?? '').toString(),
        currency: currencyOrInr(row['currency']),
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        itemsSubtotal: subtotal,
        deliveryFee: delivery,
        totalAmount: subtotal + delivery,
        paymentMethod: pm,
        paymentStatus: _orderPaymentStatusRaw(row),
        razorpayPaymentId: _razorpayPaymentIdFromRow(row),
      );
    }).toList();

    final q = searchQuery?.trim();
    if (q == null || q.isEmpty) return rows;
    return _filterAdminOrdersBySearch(rows, q);
  }

  /// Client-side filter plus [order_items] title / product_id lookup for product search.
  Future<List<AdminOrderRow>> _filterAdminOrdersBySearch(
    List<AdminOrderRow> rows,
    String rawQuery,
  ) async {
    final qLower = rawQuery.toLowerCase();
    final qNorm = qLower.replaceAll('-', '');
    final sanitized = sanitizeOrderSearchIlike(rawQuery);
    final productOrderIds = <String>{};

    if (sanitized.isNotEmpty) {
      try {
        final data = await client
            .from('order_items')
            .select('order_id')
            .ilike('title', '%$sanitized%');
        for (final r in (data as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          final oid = m['order_id']?.toString();
          if (oid != null && oid.isNotEmpty) productOrderIds.add(oid);
        }
      } catch (_) {}
    }

    final uuidLike = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final trimmed = rawQuery.trim();
    if (uuidLike.hasMatch(trimmed)) {
      try {
        final byPid = await client
            .from('order_items')
            .select('order_id')
            .eq('product_id', trimmed);
        for (final r in (byPid as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          final oid = m['order_id']?.toString();
          if (oid != null && oid.isNotEmpty) productOrderIds.add(oid);
        }
      } catch (_) {}
    }

    return rows.where((o) {
      if (productOrderIds.contains(o.id)) return true;
      if (orderIdMatchesSearch(o.id, qLower, qNorm)) return true;
      final uidNorm = o.userId.toLowerCase().replaceAll('-', '');
      if (uidNorm.contains(qNorm) || o.userId.toLowerCase().contains(qLower)) {
        return true;
      }
      if (o.customerName.toLowerCase().contains(qLower)) return true;
      if (o.customerEmail.toLowerCase().contains(qLower)) return true;
      if (o.status.toLowerCase().contains(qLower)) return true;
      if (o.paymentStatus.toLowerCase().contains(qLower)) return true;
      if (o.paymentMethod.toLowerCase().contains(qLower)) return true;
      return false;
    }).toList();
  }

  Future<List<AdminOrderRow>> fetchOrdersByUser(String userId) async {
    await _requireAdmin();
    List<Map<String, dynamic>> orders;
    try {
      final ordersData = await client
          .from('orders')
          .select(
            'id, user_id, status, currency, created_at, delivery_fee, customer_email, '
            'payment_method, payment_status, razorpay_payment_id',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      orders = (ordersData as List).cast<Map<String, dynamic>>();
    } catch (_) {
      final ordersData = await client
          .from('orders')
          .select(
            'id, user_id, status, currency, created_at, delivery_fee, '
            'payment_method, payment_status, razorpay_payment_id',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      orders = (ordersData as List).cast<Map<String, dynamic>>();
    }
    if (orders.isEmpty) return const [];
    final totalsByOrder = await _fetchOrderTotals(
      orders.map((e) => (e['id'] ?? '').toString()).where((e) => e.isNotEmpty).toList(),
    );
    Map<String, dynamic>? profile;
    try {
      profile = await client
          .from('profiles')
          .select('full_name, email')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      profile = await client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
    }
    final name = profile?['full_name']?.toString().trim().isNotEmpty == true
        ? profile!['full_name'].toString()
        : 'User';
    final emailById = await _fetchAuthEmailsByUserIds([userId]);
    return orders.map((row) {
      final oid = row['id'].toString();
      final subtotal = totalsByOrder[oid] ?? 0;
      final delivery = _deliveryFeeFromRow(row);
      final pm = _orderPaymentMethodRaw(row);
      return AdminOrderRow(
        id: oid,
        userId: userId,
        customerName: name,
        customerEmail: _customerEmailForOrder(
          orderSnapshotEmail: row['customer_email'],
          profileEmail: profile?['email']?.toString(),
          authMapEmail: emailById[userId],
        ),
        status: (row['status'] ?? '').toString(),
        currency: currencyOrInr(row['currency']),
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        itemsSubtotal: subtotal,
        deliveryFee: delivery,
        totalAmount: subtotal + delivery,
        paymentMethod: pm,
        paymentStatus: _orderPaymentStatusRaw(row),
        razorpayPaymentId: _razorpayPaymentIdFromRow(row),
      );
    }).toList();
  }

  Future<AdminOrderDetails> fetchOrderDetails(String orderId) async {
    await _requireAdmin();
    Map<String, dynamic> orderData;
    try {
      orderData = await client
          .from('orders')
          .select(
            'id, user_id, status, currency, created_at, delivery_fee, customer_email, '
            'shipping_full_name, shipping_phone, shipping_address_line, shipping_city, shipping_postal_code, '
            'tracking_number, courier_name, estimated_delivery_date, '
            'package_weight_kg, package_dimensions_cm, '
            'payment_method, payment_status, razorpay_payment_id, razorpay_order_id',
          )
          .eq('id', orderId)
          .single();
    } catch (_) {
      try {
        orderData = await client
            .from('orders')
            .select(
              'id, user_id, status, currency, created_at, delivery_fee, customer_email, '
              'shipping_full_name, shipping_phone, shipping_address_line, shipping_city, shipping_postal_code, '
              'payment_method, payment_status, razorpay_payment_id, razorpay_order_id',
            )
            .eq('id', orderId)
            .single();
      } catch (_) {
        try {
          orderData = await client
              .from('orders')
              .select(
                'id, user_id, status, currency, created_at, delivery_fee, '
                'shipping_full_name, shipping_phone, shipping_address_line, shipping_city, shipping_postal_code, '
                'payment_method, payment_status, razorpay_payment_id, razorpay_order_id',
              )
              .eq('id', orderId)
              .single();
        } catch (_) {
          orderData = await client
              .from('orders')
              .select('id, user_id, status, currency, created_at')
              .eq('id', orderId)
              .single();
        }
      }
    }
    final orderMap = orderData;
    final userId = orderMap['user_id']?.toString() ?? '';

    Map<String, dynamic>? profile;
    if (userId.isEmpty) {
      profile = null;
    } else {
      try {
        profile = await client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();
      } catch (_) {
        profile = await client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
      }
    }
    final emailById = await _fetchAuthEmailsByUserIds(
      userId.isEmpty ? const [] : [userId],
    );

    final itemsData = await client
        .from('order_items')
        .select('id, order_id, product_id, title, image_urls, unit_price, currency, quantity')
        .eq('order_id', orderId);
    final items = (itemsData as List).cast<Map<String, dynamic>>().map((e) {
      final imageData = e['image_urls'];
      final rawUrls = imageData is List ? imageData.map((v) => v.toString()).toList() : const <String>[];
      final oid = e['id']?.toString().trim();
      return AdminOrderItemRow(
        orderItemId: oid != null && oid.isNotEmpty ? oid : null,
        productId: (e['product_id'] ?? '').toString(),
        title: (e['title'] ?? '').toString(),
        quantity: (e['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (e['unit_price'] as num?)?.toDouble() ?? 0,
        currency: currencyOrInr(e['currency']),
        imageUrls: rawUrls.map(_normalizeImageUrl).toList(),
      );
    }).toList();

    final itemsSubtotal = items.fold<double>(0, (sum, i) => sum + (i.unitPrice * i.quantity));
    final deliveryFee = _deliveryFeeFromRow(orderMap);
    final pmRaw = _orderPaymentMethodRaw(orderMap);
    final psRaw = _orderPaymentStatusRaw(orderMap);
    final rzpId = _razorpayPaymentIdFromRow(orderMap);
    final rzpOid = _razorpayOrderIdFromRow(orderMap);
    final order = AdminOrderRow(
      id: orderMap['id'].toString(),
      userId: userId,
      customerName: profile?['full_name']?.toString().trim().isNotEmpty == true
          ? profile!['full_name'].toString()
          : 'User',
      customerEmail: _customerEmailForOrder(
        orderSnapshotEmail: orderMap['customer_email'],
        profileEmail: profile?['email']?.toString(),
        authMapEmail: emailById[userId],
      ),
      status: (orderMap['status'] ?? '').toString(),
      currency: currencyOrInr(orderMap['currency']),
      createdAt: DateTime.tryParse(orderMap['created_at']?.toString() ?? '') ?? DateTime.now(),
      itemsSubtotal: itemsSubtotal,
      deliveryFee: deliveryFee,
      totalAmount: itemsSubtotal + deliveryFee,
      paymentMethod: pmRaw,
      paymentStatus: psRaw,
      razorpayPaymentId: rzpId,
    );

    final shipName = orderMap['shipping_full_name']?.toString().trim();
    final shipPhone = orderMap['shipping_phone']?.toString().trim();
    final shipLine = orderMap['shipping_address_line']?.toString().trim();
    final shipCity = orderMap['shipping_city']?.toString().trim();
    final shipPin = orderMap['shipping_postal_code']?.toString().trim();
    final shippingAddress = _formatShippingSnapshot(
      fullName: shipName,
      phone: shipPhone,
      addressLine: shipLine,
      city: shipCity,
      postalCode: shipPin,
    );
    final paymentMethodLabel = _paymentMethodDisplayLabel(pmRaw);

    final trackRaw = orderMap['tracking_number']?.toString().trim();
    final courierRaw = orderMap['courier_name']?.toString().trim();
    final estRaw = orderMap['estimated_delivery_date'];
    final trackingNumber = trackRaw != null && trackRaw.isNotEmpty ? trackRaw : null;
    final courierName = courierRaw != null && courierRaw.isNotEmpty ? courierRaw : null;
    final estimatedDeliveryDate = parseEstimatedDeliveryFromDb(estRaw);
    final pkgW = orderMap['package_weight_kg'];
    final packageWeightKg = pkgW is num ? pkgW.toDouble() : double.tryParse(pkgW?.toString() ?? '');
    final dimRaw = orderMap['package_dimensions_cm']?.toString().trim();
    final packageDimensionsCm =
        dimRaw != null && dimRaw.isNotEmpty ? dimRaw : null;

    List<AdminOrderTimelineEvent> timeline;
    try {
      final histData = await client
          .from('order_status_history')
          .select('status, notes, created_at')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      final rows = (histData as List).cast<Map<String, dynamic>>();
      timeline = rows.map((row) {
        final st = (row['status'] ?? '').toString();
        final noteRaw = row['notes']?.toString().trim();
        return AdminOrderTimelineEvent(
          label: _orderStatusLabelForTimeline(st),
          timestamp:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          notes: noteRaw != null && noteRaw.isNotEmpty ? noteRaw : null,
        );
      }).toList();
    } catch (_) {
      timeline = _buildOrderTimeline(
        createdAt: order.createdAt,
        status: order.status,
      );
    }

    return AdminOrderDetails(
      order: order,
      items: items,
      shippingAddress: shippingAddress,
      shippingFullName: shipName?.isEmpty ?? true ? null : shipName,
      shippingPhone: shipPhone?.isEmpty ?? true ? null : shipPhone,
      shippingAddressLine: shipLine?.isEmpty ?? true ? null : shipLine,
      shippingCity: shipCity?.isEmpty ?? true ? null : shipCity,
      shippingPostalCode: shipPin?.isEmpty ?? true ? null : shipPin,
      paymentMethod: paymentMethodLabel,
      paymentStatus: psRaw,
      razorpayPaymentId: rzpId,
      razorpayOrderId: rzpOid,
      timeline: timeline,
      trackingNumber: trackingNumber,
      courierName: courierName,
      estimatedDeliveryDate: estimatedDeliveryDate,
      packageWeightKg: packageWeightKg,
      packageDimensionsCm: packageDimensionsCm,
    );
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? notes,
  }) async {
    await _requireAdmin();
    String? oldStatus;
    try {
      final row = await client.from('orders').select('status').eq('id', orderId).single();
      oldStatus = row['status']?.toString();
    } catch (_) {}
    final normalizedStatus = _normalizeOrderStatus(status);
    try {
      await client.rpc(
        'admin_set_order_status',
        params: {
          'p_order_id': orderId,
          'p_new_status': normalizedStatus,
          'p_notes': notes,
        },
      );
    } catch (_) {
      await client.from('orders').update({'status': normalizedStatus}).eq('id', orderId);
    }
    final isCancelled = normalizedStatus == 'cancelled';
    final message = isCancelled
        ? 'Admin cancelled order $orderId${oldStatus != null ? ' (was $oldStatus)' : ''}'
        : 'Admin updated order status: ${oldStatus ?? '?'} → $normalizedStatus (order $orderId)';
    await _logAdminAction(
      action: isCancelled ? 'order_cancelled' : 'order_status_changed',
      entity: 'order',
      entityId: orderId,
      message: message,
    );
  }

  Future<void> approveOrderCancellation({
    required String orderId,
    String? notes,
  }) async {
    await _requireAdmin();
    try {
      await client.rpc(
        'admin_approve_order_cancellation',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_notes': notes,
        },
      );
    } on PostgrestException catch (e) {
      throw RepositoryException(e.message.trim().isNotEmpty ? e.message : e.toString());
    }
    await _logAdminAction(
      action: 'order_cancellation_approved',
      entity: 'order',
      entityId: orderId,
      message: 'Admin approved cancellation for order $orderId',
    );
  }

  Future<void> rejectOrderCancellation({
    required String orderId,
    String? notes,
  }) async {
    await _requireAdmin();
    try {
      await client.rpc(
        'admin_reject_order_cancellation',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_notes': notes,
        },
      );
    } on PostgrestException catch (e) {
      throw RepositoryException(e.message.trim().isNotEmpty ? e.message : e.toString());
    }
    await _logAdminAction(
      action: 'order_cancellation_rejected',
      entity: 'order',
      entityId: orderId,
      message: 'Admin rejected cancellation request for order $orderId',
    );
  }

  Future<void> updateOrderShipmentInfo({
    required String orderId,
    required String trackingNumber,
    required String courierName,
    DateTime? estimatedDeliveryDate,
    double? packageWeightKg,
    String? packageDimensionsCm,
  }) async {
    await _requireAdmin();
    String? statusRaw;
    try {
      final row = await client.from('orders').select('status').eq('id', orderId).single();
      statusRaw = row['status']?.toString();
    } catch (_) {}
    final terminal = canonicalAdminOrderStatus(statusRaw ?? '');
    if (terminal == 'delivered' || terminal == 'cancelled') {
      throw RepositoryException(
        'Shipment details cannot be changed after the order is ${terminal == 'delivered' ? 'delivered' : 'cancelled'}.',
      );
    }
    final payload = <String, dynamic>{
      'tracking_number':
          trackingNumber.trim().isEmpty ? null : trackingNumber.trim(),
      'courier_name': courierName.trim().isEmpty ? null : courierName.trim(),
      'estimated_delivery_date': estimatedDeliveryDate == null
          ? null
          : estimatedDeliveryToDbIso(estimatedDeliveryDate),
      if (packageWeightKg != null) 'package_weight_kg': packageWeightKg,
      if (packageDimensionsCm != null && packageDimensionsCm.trim().isNotEmpty)
        'package_dimensions_cm': packageDimensionsCm.trim(),
    };
    await client.from('orders').update(payload).eq('id', orderId);
    await _logAdminAction(
      action: 'order_shipment_updated',
      entity: 'order',
      entityId: orderId,
      message: 'Admin updated shipment details for order $orderId',
    );
  }

  String _resolveUserEmail(String? profileEmail, String? authEmail) {
    bool usable(String? s) {
      final t = s?.trim();
      return t != null && t.isNotEmpty && t != '-';
    }

    if (usable(profileEmail)) return profileEmail!.trim();
    if (usable(authEmail)) return authEmail!.trim();
    return '-';
  }

  /// Prefer email stored on the order row (server snapshot), then profile, then auth.users map.
  String _customerEmailForOrder({
    required dynamic orderSnapshotEmail,
    required String? profileEmail,
    required String? authMapEmail,
  }) {
    final snap = orderSnapshotEmail?.toString().trim();
    if (snap != null && snap.isNotEmpty && snap != '-') return snap;
    return _resolveUserEmail(profileEmail, authMapEmail);
  }

  Future<List<AdminUserRow>> fetchUsers() async {
    await _requireAdmin();
    List<Map<String, dynamic>> profiles;
    try {
      final profilesData =
          await client
              .from('profiles')
              .select('id, full_name, created_at, email, role, status, blocked_reason, blocked_at');
      profiles = (profilesData as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        final profilesData = await client
            .from('profiles')
            .select('id, full_name, created_at, email, role');
        profiles = (profilesData as List).cast<Map<String, dynamic>>();
      } catch (_) {
        final profilesData = await client.from('profiles').select('id, full_name, created_at, role');
        profiles = (profilesData as List).cast<Map<String, dynamic>>();
      }
    }
    final profileById = {
      for (final p in profiles) (p['id'] ?? '').toString(): p,
    }..remove('');

    // Try to include all authenticated users, not only profiles rows.
    List<Map<String, dynamic>> authUsers = const [];
    try {
      final data = await client
          .schema('auth')
          .from('users')
          .select('id, email, created_at');
      authUsers = (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // Fallback gracefully when auth.users is restricted.
      authUsers = const [];
    }
    final authById = {
      for (final u in authUsers) (u['id'] ?? '').toString(): u,
    }..remove('');

    final ordersData = await client.from('orders').select('id, user_id');
    final orders = (ordersData as List).cast<Map<String, dynamic>>();
    final orderIdsByUser = <String, List<String>>{};
    for (final order in orders) {
      final userId = (order['user_id'] ?? '').toString();
      final orderId = (order['id'] ?? '').toString();
      if (userId.isEmpty || orderId.isEmpty) continue;
      orderIdsByUser.putIfAbsent(userId, () => []).add(orderId);
    }

    final totalSpentByUser = await _fetchTotalSpentByUser();

    final allUserIds = <String>{
      ...profileById.keys,
      ...authById.keys,
      ...orderIdsByUser.keys,
    }.toList();
    allUserIds.sort();

    return allUserIds.map((id) {
      final p = profileById[id];
      final a = authById[id];
      final orderIds = orderIdsByUser[id] ?? const <String>[];
      final spent = totalSpentByUser[id] ?? 0;
      final email = _resolveUserEmail(p?['email']?.toString(), a?['email']?.toString());
      final fullName = p?['full_name']?.toString().trim();
      final displayName = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (email != '-' ? email.split('@').first : 'User ${id.substring(0, id.length >= 8 ? 8 : id.length)}');
      final createdAtRaw = p?['created_at'] ?? a?['created_at'];
      final roleRaw = p?['role']?.toString().trim().toLowerCase();
      final role = switch (roleRaw) {
        'admin' => 'admin',
        'super_admin' => 'super_admin',
        _ => 'customer',
      };
      final statusRaw = p?['status']?.toString().trim().toLowerCase();
      final status = statusRaw == 'blocked' ? 'blocked' : 'active';
      final blockedReasonRaw = p?['blocked_reason']?.toString().trim();
      final blockedReason = (blockedReasonRaw != null && blockedReasonRaw.isNotEmpty)
          ? blockedReasonRaw
          : null;
      final blockedAtRaw = p?['blocked_at']?.toString();

      return AdminUserRow(
        id: id,
        fullName: displayName,
        email: email,
        role: role,
        totalOrders: orderIds.length,
        totalSpent: spent,
        createdAt: createdAtRaw == null
            ? null
            : DateTime.tryParse(createdAtRaw.toString()),
        status: status,
        blockedReason: blockedReason,
        blockedAt: blockedAtRaw == null ? null : DateTime.tryParse(blockedAtRaw),
      );
    }).toList();
  }

  Future<Map<String, double>> _fetchTotalSpentByUser() async {
    final ordersData = await client.from('orders').select('id, user_id, delivery_fee');
    final orders = (ordersData as List).cast<Map<String, dynamic>>();
    if (orders.isEmpty) return const {};

    final orderIds =
        orders.map((o) => (o['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    final subtotalsByOrder = await _fetchOrderTotals(orderIds);

    final totalByUser = <String, double>{};
    for (final o in orders) {
      final oid = (o['id'] ?? '').toString();
      final userId = (o['user_id'] ?? '').toString();
      if (oid.isEmpty || userId.isEmpty) continue;
      final grand = (subtotalsByOrder[oid] ?? 0) + _deliveryFeeFromRow(o);
      totalByUser[userId] = (totalByUser[userId] ?? 0) + grand;
    }
    return totalByUser;
  }

  Future<AdminUserDetails?> fetchUserDetails(String userId) async {
    await _requireAdmin();
    final users = await fetchUsers();
    final user = users.where((u) => u.id == userId).toList();
    if (user.isEmpty) return null;
    final orders = await fetchOrdersByUser(userId);
    Map<String, dynamic>? profile;
    try {
      profile = await client
          .from('profiles')
          .select('phone, address, email, role, status, blocked_reason, blocked_at')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      try {
        profile = await client
            .from('profiles')
            .select('phone, address, email, role')
            .eq('id', userId)
            .maybeSingle();
      } catch (_) {
        try {
          profile = await client
              .from('profiles')
              .select('phone, address')
              .eq('id', userId)
              .maybeSingle();
        } catch (_) {
          profile = await client
              .from('profiles')
              .select('id')
              .eq('id', userId)
              .maybeSingle();
        }
      }
    }

    final baseUser = user.first;
    var displayEmail = _resolveUserEmail(profile?['email']?.toString(), null);
    if (displayEmail == '-') {
      displayEmail = baseUser.email;
    }
    if (displayEmail == '-' || displayEmail.isEmpty) {
      final authEmails = await _fetchAuthEmailsByUserIds([userId]);
      displayEmail = _resolveUserEmail(null, authEmails[userId]);
    }

    final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
    final totalOrders = orders.length;
    final averageOrderValue = totalOrders == 0 ? 0.0 : totalRevenue / totalOrders;
    DateTime? firstOrderDate;
    DateTime? lastOrderDate;
    if (orders.isNotEmpty) {
      final sorted = [...orders]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      firstOrderDate = sorted.first.createdAt;
      lastOrderDate = sorted.last.createdAt;
    }

    return AdminUserDetails(
      user: AdminUserRow(
        id: baseUser.id,
        fullName: baseUser.fullName,
        email: displayEmail,
        role: () {
          final r = profile?['role']?.toString().trim().toLowerCase();
          if (r == 'admin' || r == 'super_admin' || r == 'customer') return r!;
          return baseUser.role;
        }(),
        totalOrders: baseUser.totalOrders,
        totalSpent: baseUser.totalSpent,
        createdAt: baseUser.createdAt,
        status: (profile?['status']?.toString().trim().toLowerCase() == 'blocked')
            ? 'blocked'
            : baseUser.status,
        blockedReason: () {
          final v = profile?['blocked_reason']?.toString().trim();
          if (v == null || v.isEmpty) return baseUser.blockedReason;
          return v;
        }(),
        blockedAt: () {
          final raw = profile?['blocked_at']?.toString();
          if (raw == null || raw.isEmpty) return baseUser.blockedAt;
          return DateTime.tryParse(raw);
        }(),
      ),
      orders: orders,
      phone: profile?['phone']?.toString() ?? '-',
      address: profile?['address']?.toString() ?? '-',
      firstOrderDate: firstOrderDate,
      lastOrderDate: lastOrderDate,
      averageOrderValue: averageOrderValue,
      totalRevenue: totalRevenue,
    );
  }

  Future<void> setUserBlocked(
    String userId, {
    required bool blocked,
    String? reason,
  }) async {
    await _requireAdmin();
    final targetUserId = userId.trim();
    if (targetUserId.isEmpty) {
      throw const ValidationException('User id is required.');
    }

    final me = client.auth.currentUser?.id;
    if (blocked && me != null && me == targetUserId) {
      throw const ValidationException('You cannot block your own admin account.');
    }

    final reasonClean = reason?.trim();
    final payload = <String, dynamic>{
      'status': blocked ? 'blocked' : 'active',
      'blocked_reason': blocked
          ? ((reasonClean == null || reasonClean.isEmpty) ? null : reasonClean)
          : null,
      'blocked_at': blocked ? DateTime.now().toUtc().toIso8601String() : null,
    };

    await client.from('profiles').update(payload).eq('id', targetUserId);
  }

  Future<void> setUserRole(
    String userId, {
    required String role,
  }) async {
    await _requireAdmin();
    final isSuperAdmin = await isCurrentUserSuperAdmin();
    if (!isSuperAdmin) {
      throw const AuthException('Super admin role required.');
    }
    final targetUserId = userId.trim();
    if (targetUserId.isEmpty) {
      throw const ValidationException('User id is required.');
    }
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != 'admin' &&
        normalizedRole != 'customer' &&
        normalizedRole != 'super_admin') {
      throw const ValidationException('Invalid role.');
    }

    final me = client.auth.currentUser?.id;
    if (me != null && me == targetUserId && normalizedRole != 'super_admin') {
      throw const ValidationException(
        'You cannot remove your own super admin access.',
      );
    }

    final existing = await client
        .from('profiles')
        .select('role')
        .eq('id', targetUserId)
        .maybeSingle();
    final targetCurrentRole = existing?['role']?.toString().trim().toLowerCase();
    if (targetCurrentRole == 'super_admin' && normalizedRole != 'super_admin') {
      throw const ValidationException(
        'Super admin role can only be changed manually in a controlled process.',
      );
    }

    await client.from('profiles').update({'role': normalizedRole}).eq('id', targetUserId);
  }

  /// Uploads to [product-images] at `homepage/{folder}/…` for storefront merchandising.
  Future<String> uploadHomepageImage({
    required String folder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _requireAdmin();
    final safeFolder = folder.replaceAll(RegExp(r'[^\w\-]'), '');
    if (safeFolder.isEmpty) {
      throw ArgumentError('folder is required');
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final objectPath = 'homepage/$safeFolder/${stamp}_$sanitized.jpg';
    await client.storage.from('product-images').uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return client.storage.from('product-images').getPublicUrl(objectPath);
  }

  Future<List<AdminHomeHeroBannerRow>> fetchHomeHeroBannersAdmin() async {
    await _requireAdmin();
    final data = await client
        .from('homepage_hero_banners')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AdminHomeHeroBannerRow.fromJson)
        .toList();
  }

  static String _titleCaseFromSlug(String slug) {
    return slug
        .split(RegExp(r'[_\-\s]+'))
        .where((e) => e.isNotEmpty)
        .map((w) => w.length == 1 ? w.toUpperCase() : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<List<AdminCategoryOption>> fetchCatalogCategoryOptions() async {
    await _requireAdmin();
    try {
      final catData = await client
          .from('categories')
          .select('name, slug')
          .order('display_order', ascending: true)
          .order('name', ascending: true);
      final fromTable = <AdminCategoryOption>[];
      final inTable = <String>{};
      for (final row in (catData as List).cast<Map<String, dynamic>>()) {
        final slug = row['slug']?.toString().trim().toLowerCase() ?? '';
        final name = row['name']?.toString().trim() ?? '';
        if (slug.isEmpty) continue;
        inTable.add(slug);
        fromTable.add(AdminCategoryOption(slug: slug, label: name.isNotEmpty ? name : slug));
      }
      if (fromTable.isNotEmpty) {
        final prodData = await client.from('products').select('category').eq('is_active', true);
        final extras = <AdminCategoryOption>[];
        for (final row in (prodData as List).cast<Map<String, dynamic>>()) {
          final raw = row['category']?.toString().trim().toLowerCase() ?? '';
          if (raw.isEmpty || inTable.contains(raw)) continue;
          inTable.add(raw);
          extras.add(AdminCategoryOption(slug: raw, label: _titleCaseFromSlug(raw)));
        }
        extras.sort((a, b) => a.slug.compareTo(b.slug));
        return [...fromTable, ...extras];
      }
    } catch (_) {
      // Table may not exist on older databases; fall through.
    }
    final data = await client.from('products').select('category').eq('is_active', true);
    final slugs = <String>{};
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final raw = row['category']?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty) continue;
      slugs.add(raw);
    }
    final sorted = slugs.toList()..sort();
    return sorted
        .map(
          (slug) => AdminCategoryOption(
            slug: slug,
            label: _titleCaseFromSlug(slug),
          ),
        )
        .toList();
  }

  Future<List<AdminCatalogCategoryRow>> fetchCatalogCategoriesAdmin() async {
    await _requireAdmin();
    final data = await client
        .from('categories')
        .select()
        .order('display_order', ascending: true)
        .order('name', ascending: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AdminCatalogCategoryRow.fromJson)
        .toList();
  }

  Future<int> _nextCategoryDisplayOrder() async {
    final rows = await client
        .from('categories')
        .select('display_order')
        .order('display_order', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) {
      final v = rows.first['display_order'];
      return (v is num ? v.toInt() : 0) + 10;
    }
    return 0;
  }

  Future<void> insertCatalogCategory({
    required String name,
    required String slug,
    String? imageUrl,
    bool isActive = true,
    bool showInShop = true,
    int? displayOrder,
  }) async {
    await _requireAdmin();
    final order = displayOrder ?? await _nextCategoryDisplayOrder();
    await client.from('categories').insert({
      'name': name.trim(),
      'slug': slug.trim().toLowerCase(),
      'image_url': imageUrl,
      'is_active': isActive,
      'show_in_shop': showInShop,
      'display_order': order,
    });
    await _logAdminAction(
      action: 'catalog_category_created',
      entity: 'categories',
      entityId: '-',
      message: 'Admin added category "${name.trim()}"',
    );
  }

  Future<void> updateCatalogCategory({
    required String id,
    required String name,
    required String slug,
    String? imageUrl,
    required bool isActive,
    required bool showInShop,
    required int displayOrder,
  }) async {
    await _requireAdmin();
    await client.from('categories').update({
      'name': name.trim(),
      'slug': slug.trim().toLowerCase(),
      'image_url': imageUrl,
      'is_active': isActive,
      'show_in_shop': showInShop,
      'display_order': displayOrder,
    }).eq('id', id);
    await _logAdminAction(
      action: 'catalog_category_updated',
      entity: 'categories',
      entityId: id,
      message: 'Admin updated category "${name.trim()}"',
    );
  }

  Future<void> deleteCatalogCategory(String id) async {
    await _requireAdmin();
    await client.from('categories').delete().eq('id', id);
    await _logAdminAction(
      action: 'catalog_category_deleted',
      entity: 'categories',
      entityId: id,
      message: 'Admin deleted a category',
    );
  }

  Future<void> reorderCatalogCategories(List<String> orderedIds) async {
    await _requireAdmin();
    for (var i = 0; i < orderedIds.length; i++) {
      await client.from('categories').update({'display_order': i * 10}).eq('id', orderedIds[i]);
    }
    await _logAdminAction(
      action: 'catalog_categories_reordered',
      entity: 'categories',
      entityId: '-',
      message: 'Admin reordered categories',
    );
  }

  Future<int> _nextSortOrderFor(String table) async {
    final rows = await client.from(table).select('sort_order').order('sort_order', ascending: false).limit(1);
    if (rows.isNotEmpty) {
      final v = rows.first['sort_order'];
      return (v is num ? v.toInt() : 0) + 1;
    }
    return 0;
  }

  Future<void> insertHomeHeroBanner({
    required String imageUrl,
    required String redirectType,
    required String redirectValue,
    int? sortOrder,
    bool enabled = true,
  }) async {
    await _requireAdmin();
    final computedSort = sortOrder ?? await _nextSortOrderFor('homepage_hero_banners');
    final row = {
      'image_url': imageUrl,
      'redirect_type': redirectType,
      'redirect_value': redirectValue,
      'sort_order': computedSort,
      'enabled': enabled,
    };
    try {
      await client.from('homepage_hero_banners').insert(row);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final legacyConstraintFail = msg.contains('redirect_type') || msg.contains('check constraint');
      final canFallback = legacyConstraintFail &&
          (redirectType == 'external_link' || redirectType == 'collection' || redirectType == 'no_redirect');
      if (!canFallback) rethrow;
      // Legacy DB compatibility: older schema only allowed `path`.
      await client.from('homepage_hero_banners').insert({
        ...row,
        'redirect_type': 'path',
      });
    }
    await _logAdminAction(
      action: 'homepage_banner_created',
      entity: 'homepage_hero_banners',
      entityId: '-',
      message: 'Admin added hero banner (redirect $redirectType)',
    );
  }

  Future<void> reorderHomeHeroBanners(List<String> orderedIds) async {
    await _requireAdmin();
    for (var i = 0; i < orderedIds.length; i++) {
      await client.from('homepage_hero_banners').update({'sort_order': i}).eq('id', orderedIds[i]);
    }
  }

  Future<void> updateHomeHeroBanner({
    required String id,
    required String imageUrl,
    required String redirectType,
    required String redirectValue,
    required int sortOrder,
    required bool enabled,
  }) async {
    await _requireAdmin();
    final row = {
      'image_url': imageUrl,
      'redirect_type': redirectType,
      'redirect_value': redirectValue,
      'sort_order': sortOrder,
      'enabled': enabled,
    };
    try {
      await client.from('homepage_hero_banners').update(row).eq('id', id);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final legacyConstraintFail = msg.contains('redirect_type') || msg.contains('check constraint');
      final canFallback = legacyConstraintFail &&
          (redirectType == 'external_link' || redirectType == 'collection' || redirectType == 'no_redirect');
      if (!canFallback) rethrow;
      await client.from('homepage_hero_banners').update({
        ...row,
        'redirect_type': 'path',
      }).eq('id', id);
    }
    await _logAdminAction(
      action: 'homepage_banner_updated',
      entity: 'homepage_hero_banners',
      entityId: id,
      message: 'Admin updated hero banner',
    );
  }

  Future<void> deleteHomeHeroBanner(String id) async {
    await _requireAdmin();
    await client.from('homepage_hero_banners').delete().eq('id', id);
    await _logAdminAction(
      action: 'homepage_banner_deleted',
      entity: 'homepage_hero_banners',
      entityId: id,
      message: 'Admin deleted hero banner',
    );
  }

  Future<List<AdminHomeTopCategoryRow>> fetchHomeTopCategoriesAdmin() async {
    await _requireAdmin();
    final data = await client
        .from('homepage_top_categories')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AdminHomeTopCategoryRow.fromJson)
        .toList();
  }

  Future<void> insertHomeTopCategory({
    required String label,
    required String iconUrl,
    required String categorySlug,
    int? sortOrder,
    bool enabled = true,
  }) async {
    await _requireAdmin();
    final computedSort = sortOrder ?? await _nextSortOrderFor('homepage_top_categories');
    await client.from('homepage_top_categories').insert({
      'label': label,
      'icon_url': iconUrl,
      'category_slug': categorySlug.trim().toLowerCase(),
      'sort_order': computedSort,
      'enabled': enabled,
    });
    await _logAdminAction(
      action: 'homepage_top_category_created',
      entity: 'homepage_top_categories',
      entityId: '-',
      message: 'Admin added top category "$label"',
    );
  }

  Future<void> reorderHomeTopCategories(List<String> orderedIds) async {
    await _requireAdmin();
    for (var i = 0; i < orderedIds.length; i++) {
      await client.from('homepage_top_categories').update({'sort_order': i}).eq('id', orderedIds[i]);
    }
  }

  Future<void> updateHomeTopCategory({
    required String id,
    required String label,
    required String iconUrl,
    required String categorySlug,
    required int sortOrder,
    required bool enabled,
  }) async {
    await _requireAdmin();
    await client.from('homepage_top_categories').update({
      'label': label,
      'icon_url': iconUrl,
      'category_slug': categorySlug.trim().toLowerCase(),
      'sort_order': sortOrder,
      'enabled': enabled,
    }).eq('id', id);
    await _logAdminAction(
      action: 'homepage_top_category_updated',
      entity: 'homepage_top_categories',
      entityId: id,
      message: 'Admin updated top category "$label"',
    );
  }

  Future<void> deleteHomeTopCategory(String id) async {
    await _requireAdmin();
    await client.from('homepage_top_categories').delete().eq('id', id);
    await _logAdminAction(
      action: 'homepage_top_category_deleted',
      entity: 'homepage_top_categories',
      entityId: id,
      message: 'Admin deleted top category',
    );
  }

  /// Uploads to [product-images] bucket at `products/{productId}/image_*.jpg`.
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _requireAdmin();
    final safeId = productId.trim();
    if (safeId.isEmpty) {
      throw ArgumentError('productId is required for image upload');
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final objectPath = 'products/$safeId/image_${stamp}_$sanitized.jpg';
    await client.storage
        .from('product-images')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return client.storage.from('product-images').getPublicUrl(objectPath);
  }

  /// Strip characters that break PostgREST `.or()` / `ilike` filters.
  static String _sanitizeSearchInput(String raw) {
    return raw.replaceAll(RegExp(r'[%_,()]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<List<AdminSearchResultItem>> searchGlobal(String keyword) async {
    await _requireAdmin();
    final query = keyword.trim();
    if (query.isEmpty) return const [];

    final safe = _sanitizeSearchInput(query);
    if (safe.isEmpty) return const [];

    /// PostgREST `.ilike` via query builder encodes `%` correctly; avoid `id.ilike` on uuid columns
    /// (Postgres has no `~~*` for uuid — the whole search used to fail).
    final ilikePattern = '%$safe%';

    final uuidStrict = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    Future<List<AdminSearchResultItem>> fetchProducts() async {
      try {
        final data = await client
            .from('products')
            .select('id, title, category, sku, brand')
            .or(
              'title.ilike.$ilikePattern,category.ilike.$ilikePattern,sku.ilike.$ilikePattern,brand.ilike.$ilikePattern',
            )
            .limit(8);
        return _mapProductRows((data as List).cast<Map<String, dynamic>>());
      } catch (_) {
        try {
          final data = await client
              .from('products')
              .select('id, title, category, description')
              .or(
                'title.ilike.$ilikePattern,category.ilike.$ilikePattern,description.ilike.$ilikePattern',
              )
              .limit(8);
          return _mapProductRows((data as List).cast<Map<String, dynamic>>());
        } catch (_) {
          try {
            final data = await client
                .from('products')
                .select('id, title, category')
                .or('title.ilike.$ilikePattern,category.ilike.$ilikePattern')
                .limit(8);
            return _mapProductRows((data as List).cast<Map<String, dynamic>>());
          } catch (_) {
            return const [];
          }
        }
      }
    }

    Future<List<AdminSearchResultItem>> fetchOrders() async {
      final byId = <String, Map<String, dynamic>>{};
      void addRows(List<dynamic> rows) {
        for (final r in rows) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty) byId[id] = m;
        }
      }

      try {
        if (uuidStrict.hasMatch(query)) {
          final one = await client
              .from('orders')
              .select('id, status')
              .eq('id', query)
              .maybeSingle();
          if (one != null) addRows([one]);
        }

        final byStatus = await client
            .from('orders')
            .select('id, status')
            .ilike('status', ilikePattern)
            .limit(8);
        addRows(byStatus as List);

        if (byId.length < 8) {
          try {
            final asText = await client
                .from('orders')
                .select('id, status')
                .filter('id::text', 'ilike', ilikePattern)
                .limit(8);
            addRows(asText as List);
          } catch (_) {}
        }
      } catch (_) {
        return const [];
      }

      final list = byId.values.take(8).toList();
      return list.map((row) {
        final id = (row['id'] ?? '').toString();
        return AdminSearchResultItem(
          type: 'order',
          id: id,
          title: 'Order $id',
          subtitle: 'Status: ${(row['status'] ?? '-').toString()}',
        );
      }).toList();
    }

    Future<List<AdminSearchResultItem>> fetchUsers() async {
      final byId = <String, Map<String, dynamic>>{};
      void addRows(List<dynamic> rows) {
        for (final r in rows) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty) byId[id] = m;
        }
      }

      try {
        if (uuidStrict.hasMatch(query)) {
          final one = await client
              .from('profiles')
              .select('id, full_name')
              .eq('id', query)
              .maybeSingle();
          if (one != null) addRows([one]);
        }

        final byName = await client
            .from('profiles')
            .select('id, full_name')
            .ilike('full_name', ilikePattern)
            .limit(8);
        addRows(byName as List);

        if (byId.length < 8) {
          try {
            final asText = await client
                .from('profiles')
                .select('id, full_name')
                .filter('id::text', 'ilike', ilikePattern)
                .limit(8);
            addRows(asText as List);
          } catch (_) {}
        }
      } catch (_) {
        return const [];
      }

      final list = byId.values.take(8).toList();
      return list.map((row) {
        final id = (row['id'] ?? '').toString();
        final fullName = (row['full_name'] ?? '').toString();
        return AdminSearchResultItem(
          type: 'user',
          id: id,
          title: fullName.isEmpty ? 'User $id' : fullName,
          subtitle: 'User ID: $id',
        );
      }).toList();
    }

    final chunks = await Future.wait([
      fetchProducts(),
      fetchOrders(),
      fetchUsers(),
    ]);
    return [...chunks[0], ...chunks[1], ...chunks[2]];
  }

  List<AdminSearchResultItem> _mapProductRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final sku = row['sku']?.toString().trim();
      final brand = row['brand']?.toString().trim();
      final bits = <String>[
        if ((row['category'] ?? '').toString().trim().isNotEmpty)
          'Category: ${row['category']}',
        if (sku != null && sku.isNotEmpty) 'SKU: $sku',
        if (brand != null && brand.isNotEmpty) 'Brand: $brand',
      ];
      final subtitle = bits.isEmpty ? 'Product' : bits.join(' · ');
      return AdminSearchResultItem(
        type: 'product',
        id: (row['id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        subtitle: subtitle,
      );
    }).toList();
  }

  Future<Map<String, double>> _fetchOrderTotals(List<String> orderIds) async {
    if (orderIds.isEmpty) return const {};
    final itemsData = await client
        .from('order_items')
        .select('order_id, unit_price, quantity')
        .inFilter('order_id', orderIds);
    final totals = <String, double>{};
    for (final row in (itemsData as List).cast<Map<String, dynamic>>()) {
      final orderId = (row['order_id'] ?? '').toString();
      if (orderId.isEmpty) continue;
      final unitPrice = (row['unit_price'] as num?)?.toDouble() ?? 0;
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      totals[orderId] = (totals[orderId] ?? 0) + (unitPrice * quantity);
    }
    return totals;
  }

  Future<double> _fetchRevenueForOrderIds(List<String> orderIds) async {
    if (orderIds.isEmpty) return 0;
    final subtotals = await _fetchOrderTotals(orderIds);
    final ordersData = await client
        .from('orders')
        .select('id, delivery_fee')
        .inFilter('id', orderIds);
    var sum = 0.0;
    for (final row in (ordersData as List).cast<Map<String, dynamic>>()) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      sum += (subtotals[id] ?? 0) + _deliveryFeeFromRow(row);
    }
    return sum;
  }

  static String _orderPaymentMethodRaw(Map<String, dynamic> row) {
    final raw = row['payment_method']?.toString();
    return _isCodPaymentMethodRaw(raw) ? 'cod' : 'razorpay';
  }

  static String _orderPaymentStatusRaw(Map<String, dynamic> row) {
    final s = row['payment_status']?.toString().toLowerCase().trim() ?? '';
    if (s == 'paid' || s == 'failed') return s;
    return 'pending';
  }

  static String? _razorpayPaymentIdFromRow(Map<String, dynamic> row) {
    final t = row['razorpay_payment_id']?.toString().trim();
    return t != null && t.isNotEmpty ? t : null;
  }

  static String? _razorpayOrderIdFromRow(Map<String, dynamic> row) {
    final t = row['razorpay_order_id']?.toString().trim();
    return t != null && t.isNotEmpty ? t : null;
  }

  static String _paymentMethodDisplayLabel(String raw) {
    return _isCodPaymentMethodRaw(raw) ? 'Cash on Delivery' : 'Razorpay';
  }

  static bool _isCodPaymentMethodRaw(String? raw) {
    final value = raw?.toLowerCase().trim() ?? '';
    if (value.isEmpty) return false;
    if (value == 'cod') return true;
    if (value.contains('cash') && value.contains('delivery')) return true;
    if (value.contains('cash_on_delivery')) return true;
    if (value.contains('cash on delivery')) return true;
    if (value.contains('cashondelivery')) return true;
    if (value.contains('pay_on_delivery')) return true;
    return false;
  }

  static double _deliveryFeeFromRow(Map<String, dynamic> row) {
    return (row['delivery_fee'] as num?)?.toDouble() ?? 0;
  }

  static String _formatShippingSnapshot({
    String? fullName,
    String? phone,
    String? addressLine,
    String? city,
    String? postalCode,
  }) {
    final name = fullName?.trim() ?? '';
    final ph = phone?.trim() ?? '';
    final line = addressLine?.trim() ?? '';
    final c = city?.trim() ?? '';
    final pin = postalCode?.trim() ?? '';
    if (name.isEmpty && ph.isEmpty && line.isEmpty && c.isEmpty && pin.isEmpty) {
      return '-';
    }
    final buf = StringBuffer();
    if (name.isNotEmpty) buf.writeln(name);
    if (ph.isNotEmpty) buf.writeln('Phone: $ph');
    if (line.isNotEmpty) buf.writeln(line);
    final cityPin = [c, pin].where((s) => s.isNotEmpty).join(', ');
    if (cityPin.isNotEmpty) buf.writeln(cityPin);
    return buf.toString().trim();
  }

  Future<Map<String, String>> _fetchAuthEmailsByUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    try {
      final authUsers = await client
          .schema('auth')
          .from('users')
          .select('id, email')
          .inFilter('id', userIds);
      final map = <String, String>{};
      for (final row in (authUsers as List).cast<Map<String, dynamic>>()) {
        final id = (row['id'] ?? '').toString();
        if (id.isEmpty) continue;
        map[id] = row['email']?.toString() ?? '-';
      }
      return map;
    } catch (_) {
      // Access to auth.users depends on DB grants/policies. Fallback gracefully.
      return const {};
    }
  }

  List<AdminOrderTimelineEvent> _buildOrderTimeline({
    required DateTime createdAt,
    required String status,
  }) {
    final normalized = canonicalAdminOrderStatus(status);
    var t = createdAt;

    final events = <AdminOrderTimelineEvent>[];
    void push(String label, {DateTime? at}) {
      final ts = at ?? t;
      events.add(AdminOrderTimelineEvent(label: label, timestamp: ts));
      t = ts.add(const Duration(minutes: 5));
    }

    switch (normalized) {
      case 'pending_payment':
        push('Pending payment', at: createdAt);
        break;
      case 'payment_failed':
        push('Pending payment', at: createdAt);
        push('Payment failed');
        break;
      case 'processing':
        push('Pending payment', at: createdAt);
        push('Processing');
        break;
      case 'packed':
        push('Pending payment', at: createdAt);
        push('Processing');
        push('Packed');
        break;
      case 'shipped':
        push('Pending payment', at: createdAt);
        push('Processing');
        push('Packed');
        push('Shipped');
        break;
      case 'out_for_delivery':
        push('Pending payment', at: createdAt);
        push('Processing');
        push('Packed');
        push('Shipped');
        push('Out for delivery');
        break;
      case 'delivered':
        push('Pending payment', at: createdAt);
        push('Processing');
        push('Packed');
        push('Shipped');
        push('Out for delivery');
        push('Delivered');
        break;
      case 'cancelled':
        push('Cancelled', at: createdAt);
        break;
      default:
        push(_orderStatusLabelForTimeline(normalized), at: createdAt);
    }
    return events;
  }

  static String _orderStatusLabelForTimeline(String raw) {
    switch (canonicalAdminOrderStatus(raw)) {
      case 'pending_payment':
        return 'Pending payment';
      case 'payment_failed':
        return 'Payment failed';
      case 'processing':
        return 'Processing';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'cancel_requested':
        return 'Cancel requested';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        final s = raw.trim();
        return s.isEmpty ? 'Update' : s;
    }
  }

  String _normalizeOrderStatus(String rawStatus) {
    final value = rawStatus.trim().toLowerCase();
    switch (value) {
      case 'placed':
      case 'pending':
      case 'pending payment':
        return 'pending_payment';
      case 'payment failed':
      case 'payment_failed':
        return 'payment_failed';
      case 'processing':
        return 'processing';
      case 'packed':
        return 'packed';
      case 'shipped':
      case 'shopped':
        return 'shipped';
      case 'out for delivery':
      case 'out_for_delivery':
        return 'out_for_delivery';
      case 'delivered':
      case 'completed':
        return 'delivered';
      case 'cancel requested':
      case 'cancel_requested':
        return 'cancel_requested';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return value.replaceAll(' ', '_');
    }
  }

  AdminProduct _normalizeProductImages(AdminProduct product) {
    return AdminProduct(
      id: product.id,
      title: product.title,
      description: product.description,
      category: product.category,
      sku: product.sku,
      brand: product.brand,
      tags: product.tags,
      price: product.price,
      currency: product.currency,
      weight: product.weight,
      dimensions: product.dimensions,
      inventoryCount: product.inventoryCount,
      imageUrls: product.imageUrls.map(_normalizeImageUrl).toList(),
      createdAt: product.createdAt,
      isActive: product.isActive,
      displayDiscountPercent: product.displayDiscountPercent,
      isPopular: product.isPopular,
      isRecommended: product.isRecommended,
      isFestivalSpecial: product.isFestivalSpecial,
    );
  }

  String _normalizeImageUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final objectPath = url.startsWith('/') ? url.substring(1) : url;
    return client.storage.from('product-images').getPublicUrl(objectPath);
  }

  Future<List<AdminReturnRow>> fetchReturns({String? statusFilter}) async {
    await _requireAdmin();
    dynamic q = client.from('returns').select(
          'id, order_id, user_id, product_id, order_item_id, return_reason, return_note, '
          'return_images, return_type, return_status, pickup_scheduled_at, pickup_notes, '
          'pickup_courier_partner, warehouse_receipt_at, inspection_notes, '
          'rejection_reason, replacement_order_id, created_at, updated_at, '
          'orders!returns_order_id_fkey(razorpay_payment_id), '
          'refunds(id, refund_amount, refund_method, refund_status, payment_transaction_id, '
          'razorpay_refund_id, gateway_refund_status)',
        );
    final f = statusFilter?.trim().toLowerCase();
    if (f != null && f.isNotEmpty && f != 'all') {
      q = q.eq('return_status', f);
    }
    final data = await q.order('created_at', ascending: false);
    final rows = (data as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return [];

    final itemIds = <String>{};
    final userIds = <String>{};
    for (final e in rows) {
      final oi = e['order_item_id']?.toString().trim();
      if (oi != null && oi.isNotEmpty) itemIds.add(oi);
      final u = e['user_id']?.toString().trim();
      if (u != null && u.isNotEmpty) userIds.add(u);
    }
    final itemIdList = itemIds.toList();
    final userIdList = userIds.toList();

    final Map<String, Map<String, dynamic>> itemById = {};
    if (itemIdList.isNotEmpty) {
      final itemsRes = await client
          .from('order_items')
          .select('id, title, unit_price, quantity')
          .inFilter('id', itemIdList);
      for (final r in (itemsRes as List).cast<Map<String, dynamic>>()) {
        final id = r['id']?.toString();
        if (id != null) itemById[id] = r;
      }
    }

    final Map<String, String> nameByUser = {};
    for (final uid in userIdList) {
      try {
        final p = await client
            .from('profiles')
            .select('full_name')
            .eq('id', uid)
            .maybeSingle();
        final n = p?['full_name']?.toString().trim();
        nameByUser[uid] = (n != null && n.isNotEmpty) ? n : 'User';
      } catch (_) {
        nameByUser[uid] = 'User';
      }
    }

    return rows.map((e) {
      final oid = (e['order_item_id'] ?? '').toString();
      final line = itemById[oid];
      final title = line?['title']?.toString() ?? '(item)';
      final unit = (line?['unit_price'] as num?)?.toDouble() ?? 0;
      final qty = (line?['quantity'] as num?)?.toInt() ?? 0;
      final lineAmount = unit * qty;
      final imgs = e['return_images'];
      final imageList =
          imgs is List ? imgs.map((x) => x.toString()).toList() : const <String>[];
      final uid = (e['user_id'] ?? '').toString();
      Map<String, dynamic>? refundMap;
      final refRaw = e['refunds'];
      if (refRaw is List && refRaw.isNotEmpty) {
        refundMap = Map<String, dynamic>.from(refRaw.first as Map);
      } else if (refRaw is Map) {
        refundMap = Map<String, dynamic>.from(refRaw);
      }
      return AdminReturnRow(
        id: (e['id'] ?? '').toString(),
        orderId: (e['order_id'] ?? '').toString(),
        userId: uid,
        customerName: nameByUser[uid] ?? 'User',
        productId: (e['product_id'] ?? '').toString(),
        orderItemId: oid,
        returnReason: (e['return_reason'] ?? '').toString(),
        returnType: (e['return_type'] ?? '').toString(),
        returnStatus: (e['return_status'] ?? '').toString(),
        createdAt: DateTime.tryParse(e['created_at']?.toString() ?? '') ??
            DateTime.now(),
        returnImages: imageList,
        returnNote: () {
          final t = e['return_note']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        pickupScheduledAt:
            DateTime.tryParse(e['pickup_scheduled_at']?.toString() ?? ''),
        pickupNotes: () {
          final t = e['pickup_notes']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        rejectionReason: () {
          final t = e['rejection_reason']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        lineTitle: title,
        lineAmount: lineAmount,
        refundId: refundMap?['id']?.toString(),
        refundStatus: refundMap?['refund_status']?.toString(),
        refundAmount: (refundMap?['refund_amount'] as num?)?.toDouble(),
        refundMethod: refundMap?['refund_method']?.toString(),
        paymentTransactionId: () {
          final t = refundMap?['payment_transaction_id']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        razorpayRefundId: () {
          final t = refundMap?['razorpay_refund_id']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        gatewayRefundStatus: () {
          final t = refundMap?['gateway_refund_status']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        pickupCourierPartner: () {
          final t = e['pickup_courier_partner']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        warehouseReceiptAt:
            DateTime.tryParse(e['warehouse_receipt_at']?.toString() ?? ''),
        inspectionNotes: () {
          final t = e['inspection_notes']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        orderPaymentTransactionId: () {
          final orderRaw = e['orders'];
          final orderMap = orderRaw is Map<String, dynamic>
              ? orderRaw
              : (orderRaw is Map ? Map<String, dynamic>.from(orderRaw) : null);
          final t = orderMap?['razorpay_payment_id']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
        replacementOrderId: () {
          final t = e['replacement_order_id']?.toString().trim();
          return t != null && t.isNotEmpty ? t : null;
        }(),
      );
    }).toList();
  }

  Future<void> updateReturnStatus({
    required String returnId,
    required String newStatus,
    DateTime? pickupScheduledAt,
    String? pickupNotes,
    String? rejectionReason,
    String? pickupCourierPartner,
    DateTime? warehouseReceiptAt,
    String? inspectionNotes,
  }) async {
    await _requireAdmin();
    final payload = <String, dynamic>{
      'return_status': newStatus,
    };
    if (pickupScheduledAt != null) {
      payload['pickup_scheduled_at'] = pickupScheduledAt.toUtc().toIso8601String();
    }
    if (pickupNotes != null) {
      payload['pickup_notes'] = pickupNotes.trim().isEmpty ? null : pickupNotes.trim();
    }
    if (rejectionReason != null) {
      payload['rejection_reason'] =
          rejectionReason.trim().isEmpty ? null : rejectionReason.trim();
    }
    if (pickupCourierPartner != null) {
      payload['pickup_courier_partner'] =
          pickupCourierPartner.trim().isEmpty ? null : pickupCourierPartner.trim();
    }
    if (warehouseReceiptAt != null) {
      payload['warehouse_receipt_at'] =
          warehouseReceiptAt.toUtc().toIso8601String();
    }
    if (inspectionNotes != null) {
      payload['inspection_notes'] =
          inspectionNotes.trim().isEmpty ? null : inspectionNotes.trim();
    }
    await client.from('returns').update(payload).eq('id', returnId);
    await _logAdminAction(
      action: 'return_status_updated',
      entity: 'return',
      entityId: returnId,
      message: 'Return $returnId → $newStatus',
    );
  }

  Future<void> createRefundForReturn({
    required String returnId,
    required double amount,
    required String refundMethod,
    String? paymentTransactionId,
  }) async {
    await _requireAdmin();
    final method = refundMethod.trim().toLowerCase();
    final paymentRef = paymentTransactionId?.trim();
    final ret = await client
        .from('returns')
        .select(
          'id, order_id, user_id, return_status, orders!returns_order_id_fkey(razorpay_payment_id)',
        )
        .eq('id', returnId)
        .single();
    final st = (ret['return_status'] ?? '').toString();
    if (st != 'returned') {
      throw RepositoryException(
        'Refund can only be created after the return is marked as returned.',
      );
    }
    final existing = await client.from('refunds').select('id').eq('return_id', returnId).maybeSingle();
    if (existing != null) {
      throw RepositoryException('A refund already exists for this return.');
    }
    String? resolvedPaymentRef = paymentRef;
    if (method == 'original_payment') {
      if (resolvedPaymentRef == null || resolvedPaymentRef.isEmpty) {
        final orderRaw = ret['orders'];
        final orderMap = orderRaw is Map<String, dynamic>
            ? orderRaw
            : (orderRaw is Map ? Map<String, dynamic>.from(orderRaw) : null);
        final fallback = orderMap?['razorpay_payment_id']?.toString().trim();
        if (fallback != null && fallback.isNotEmpty) {
          resolvedPaymentRef = fallback;
        }
      }
      if (resolvedPaymentRef == null || resolvedPaymentRef.isEmpty) {
        throw const ValidationException(
          'Original payment refund requires a payment reference id.',
        );
      }
    }
    try {
      await client.from('refunds').insert({
        'order_id': ret['order_id'],
        'return_id': returnId,
        'user_id': ret['user_id'],
        'refund_amount': amount,
        'refund_method': method,
        'refund_status': 'refund_initiated',
        'payment_transaction_id': resolvedPaymentRef,
      });
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('refund_exceeds_line_total')) {
        throw RepositoryException(
          'Refund amount cannot exceed the original line total (unit price × quantity).',
        );
      }
      if (msg.contains('refund_amount_positive') || msg.contains('refund_amount')) {
        throw RepositoryException('Refund amount must be greater than zero.');
      }
      if (msg.contains('return_not_ready_for_refund')) {
        throw RepositoryException(
          'Refund can only be created after the return is marked as returned.',
        );
      }
      rethrow;
    }
    await _logAdminAction(
      action: 'refund_created',
      entity: 'return',
      entityId: returnId,
      message: 'Refund initiated for return $returnId',
    );
  }

  Future<void> updateRefundStatus({
    required String refundId,
    required String newStatus,
    String? razorpayRefundId,
    String? gatewayRefundStatus,
  }) async {
    await _requireAdmin();
    final payload = <String, dynamic>{
      'refund_status': newStatus,
    };
    if (razorpayRefundId != null) {
      final t = razorpayRefundId.trim();
      if (t.isNotEmpty) payload['razorpay_refund_id'] = t;
    }
    if (gatewayRefundStatus != null) {
      final t = gatewayRefundStatus.trim();
      if (t.isNotEmpty) payload['gateway_refund_status'] = t;
    }
    try {
      await client.from('refunds').update(payload).eq('id', refundId);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid_refund_status_transition')) {
        throw RepositoryException(
          'Invalid refund status change. Allowed: initiated → processed → completed only.',
        );
      }
      if (msg.contains('refund_checklist_razorpay_refund_id_required')) {
        throw RepositoryException(
          'Razorpay refund id is required before marking this refund as processed.',
        );
      }
      if (msg.contains('refund_checklist_gateway_refund_not_verified')) {
        throw RepositoryException(
          'Gateway refund status must be verified (processed/completed) before completion.',
        );
      }
      rethrow;
    }
    await _logAdminAction(
      action: 'refund_status_updated',
      entity: 'refund',
      entityId: refundId,
      message: 'Refund $refundId → $newStatus',
    );
  }

  Future<void> _logAdminAction({
    required String action,
    required String entity,
    required String entityId,
    String? message,
  }) async {
    try {
      final adminId = client.auth.currentUser?.id;
      if (adminId == null) return;
      final row = <String, dynamic>{
        'admin_id': adminId,
        'action': action,
        'entity': entity,
        'entity_id': entityId,
      };
      if (message != null && message.isNotEmpty) {
        row['message'] = message;
      }
      await client.from('admin_logs').insert(row);
    } catch (_) {
      // If `message` column is missing (older DB), store a readable `action` string.
      try {
        final adminId = client.auth.currentUser?.id;
        if (adminId == null) return;
        final combined = (message != null && message.isNotEmpty) ? '$action: $message' : action;
        await client.from('admin_logs').insert({
          'admin_id': adminId,
          'action': combined.length > 2000 ? combined.substring(0, 2000) : combined,
          'entity': entity,
          'entity_id': entityId,
        });
      } catch (_) {
        // Logging must not break primary admin operations.
      }
    }
  }
}
