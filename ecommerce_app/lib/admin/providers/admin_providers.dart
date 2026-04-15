import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import '../services/admin_service.dart';

final adminServiceProvider = Provider<AdminService>(
  (ref) => AdminService(ref.watch(supabaseClientProvider)),
);

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardSummary>(
  (ref) => ref.read(adminServiceProvider).getDashboardStats(),
);

final adminDashboardAnalyticsProvider =
    FutureProvider.autoDispose.family<AdminDashboardAnalytics, int>(
  (ref, days) => ref.read(adminServiceProvider).fetchDashboardAnalytics(days: days),
);

final adminProductsProvider = FutureProvider.autoDispose<List<AdminProduct>>(
  (ref) => ref.read(adminServiceProvider).getProducts(),
);

/// Live query for admin order list search (debounce updates in UI).
final adminOrderSearchQueryProvider =
    NotifierProvider<AdminOrderSearchQueryNotifier, String>(
  AdminOrderSearchQueryNotifier.new,
);

class AdminOrderSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final adminOrdersProvider = FutureProvider.autoDispose<List<AdminOrderRow>>(
  (ref) {
    final q = ref.watch(adminOrderSearchQueryProvider);
    return ref.read(adminServiceProvider).getOrders(
          searchQuery: q.trim().isEmpty ? null : q.trim(),
        );
  },
);

final adminOrderDetailsProvider = FutureProvider.autoDispose.family<AdminOrderDetails, String>(
  (ref, orderId) => ref.read(adminServiceProvider).fetchOrderDetails(orderId),
);

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserRow>>(
  (ref) => ref.read(adminServiceProvider).getUsers(),
);

final adminReturnsProvider =
    FutureProvider.autoDispose.family<List<AdminReturnRow>, String>(
  (ref, statusFilter) => ref.read(adminServiceProvider).fetchReturns(
        statusFilter: statusFilter == 'all' ? null : statusFilter,
      ),
);

final adminInventoryProvider = FutureProvider.autoDispose<List<AdminInventoryRow>>(
  (ref) => ref.read(adminServiceProvider).getInventoryRows(),
);

final adminStoreDeliverySettingsProvider =
    FutureProvider.autoDispose<AdminStoreDeliverySettings>(
  (ref) => ref.read(adminServiceProvider).fetchStoreDeliverySettings(),
);

final adminUserDetailsProvider = FutureProvider.autoDispose.family<AdminUserDetails?, String>(
  (ref, userId) => ref.read(adminServiceProvider).fetchUserDetails(userId),
);

class AdminUserBlockActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setBlocked(
    String userId, {
    required bool blocked,
    String? reason,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(adminServiceProvider).setUserBlocked(
            userId,
            blocked: blocked,
            reason: reason,
          ),
    );
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminUserDetailsProvider(userId));
    state = const AsyncData(null);
  }
}

final adminUserBlockActionProvider =
    AsyncNotifierProvider<AdminUserBlockActionController, void>(
  () => AdminUserBlockActionController(),
);

class AdminUserRoleActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setRole(
    String userId, {
    required String role,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(adminServiceProvider).setUserRole(userId, role: role),
    );
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminUserDetailsProvider(userId));
    state = const AsyncData(null);
  }
}

final adminUserRoleActionProvider =
    AsyncNotifierProvider<AdminUserRoleActionController, void>(
  () => AdminUserRoleActionController(),
);

/// Parallel search across products, orders, and profiles (admin only).
final adminGlobalSearchProvider =
    FutureProvider.autoDispose.family<List<AdminSearchResultItem>, String>(
  (ref, keyword) => ref.read(adminServiceProvider).searchGlobal(keyword),
);

final adminHomeHeroBannersProvider =
    FutureProvider.autoDispose<List<AdminHomeHeroBannerRow>>(
  (ref) => ref.read(adminServiceProvider).fetchHomeHeroBannersAdmin(),
);

final adminHomeTopCategoriesProvider =
    FutureProvider.autoDispose<List<AdminHomeTopCategoryRow>>(
  (ref) => ref.read(adminServiceProvider).fetchHomeTopCategoriesAdmin(),
);

final adminCatalogCategoryOptionsProvider =
    FutureProvider.autoDispose<List<AdminCategoryOption>>(
  (ref) => ref.read(adminServiceProvider).fetchCatalogCategoryOptions(),
);

final adminCatalogCategoriesProvider =
    FutureProvider.autoDispose<List<AdminCatalogCategoryRow>>(
  (ref) => ref.read(adminServiceProvider).fetchCatalogCategoriesAdmin(),
);
