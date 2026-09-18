import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_navigation.dart';
import '../../features/auth/state/auth_session_provider.dart';
import '../../features/cart/state/cart_controller.dart';

/// Indices match [MainShell] bottom [NavigationBar] destinations.
enum StorefrontTab {
  home(0),
  categories(1),
  explore(2),
  orders(3),
  account(4);

  const StorefrontTab(this.shellIndex);
  final int shellIndex;
}

final mainShellTabIndexProvider =
    NotifierProvider<MainShellTabIndexNotifier, int>(
        MainShellTabIndexNotifier.new);

/// Incremented to notify a tab to scroll its primary list to top.
final storefrontScrollToTopSignalProvider =
    NotifierProvider<StorefrontScrollToTopSignalNotifier, Map<int, int>>(
  StorefrontScrollToTopSignalNotifier.new,
);

class StorefrontScrollToTopSignalNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => <int, int>{};

  void notify(StorefrontTab tab) {
    final next = <int, int>{...state};
    next[tab.shellIndex] = (next[tab.shellIndex] ?? 0) + 1;
    state = next;
  }
}

class MainShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void goToTab(int index) {
    state = index;
  }
}

void requestStorefrontScrollToTop(WidgetRef ref, StorefrontTab tab) {
  ref.read(storefrontScrollToTopSignalProvider.notifier).notify(tab);
}

/// Clears the stack to [MainShell] (home tab) and pushes the full product catalog.
/// Ensures system back / iOS edge swipe and the catalog app bar can return to home.
void navigateToCatalogAfterOrder(WidgetRef ref, BuildContext context) {
  ref
      .read(mainShellTabIndexProvider.notifier)
      .goToTab(StorefrontTab.home.shellIndex);
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  SchedulerBinding.instance.addPostFrameCallback((_) {
    notificationNavigatorKey.currentState?.pushNamed('/catalog');
  });
}

/// Selects a main storefront tab and pops back to the root route so the shell is visible.
Future<void> openStorefrontTab(
  WidgetRef ref,
  BuildContext context,
  StorefrontTab tab,
) async {
  const authTabs = {3, 4};
  if (authTabs.contains(tab.shellIndex)) {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null) {
      if (context.mounted) {
        await Navigator.of(context).pushNamed('/login');
      }
      return;
    }
  }
  ref.read(mainShellTabIndexProvider.notifier).goToTab(tab.shellIndex);
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Opens the cart screen via `/cart` after auth (cart is no longer a bottom tab).
Future<void> navigateToCartPage(WidgetRef ref, BuildContext context) async {
  final user = ref.read(authSessionProvider).asData?.value;
  if (user == null) {
    if (context.mounted) {
      await Navigator.of(context).pushNamed('/login');
    }
    return;
  }
  if (context.mounted) {
    await Navigator.of(context).pushNamed('/cart');
  }
}

/// After login or signup, show [MainShell] with bottom navigation.
/// Navigating only to `/profile` replaced the stack and hid Home/Categories/etc.
Future<void> goToStorefrontAfterCustomerAuth(
  WidgetRef ref,
  BuildContext context, {
  StorefrontTab tab = StorefrontTab.account,
  Map<String, dynamic>? authReturnArguments,
}) async {
  if (authReturnArguments?['action'] == 'addToCart') {
    unawaited(_resumeAddToCart(ref, context, authReturnArguments));
    return;
  }
  final returnRoute = authReturnArguments?['returnRoute']?.toString();
  if (returnRoute != null && returnRoute.isNotEmpty) {
    final returnArgs = authReturnArguments?['returnArguments'];
    Navigator.of(context).pushNamedAndRemoveUntil(
      returnRoute,
      (route) => false,
      arguments:
          returnArgs is Map ? Map<String, dynamic>.from(returnArgs) : null,
    );
    return;
  }
  ref.read(mainShellTabIndexProvider.notifier).goToTab(tab.shellIndex);
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}

Future<void> _resumeAddToCart(
  WidgetRef ref,
  BuildContext context,
  Map<String, dynamic>? authReturnArguments,
) async {
  final args = authReturnArguments?['actionArguments'];
  if (args is! Map) return;
  final productId = args['productId']?.toString().trim() ?? '';
  if (productId.isEmpty) return;
  final rawQuantity = args['quantity'];
  final quantity =
      rawQuantity is num && rawQuantity.toInt() > 0 ? rawQuantity.toInt() : 1;
  try {
    await ref.read(cartControllerProvider.notifier).addItem(
          productId: productId,
          variantId: args['variantId']?.toString(),
          quantity: quantity,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${args['productTitle'] ?? 'Item'} added to cart'),
      ),
    );
  } catch (_) {
    // Keep the authenticated user on the storefront if the resumed add fails.
  }
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
