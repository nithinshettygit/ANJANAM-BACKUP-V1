import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/auth_session_provider.dart';

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
    NotifierProvider<MainShellTabIndexNotifier, int>(MainShellTabIndexNotifier.new);

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
void goToStorefrontAfterCustomerAuth(
  WidgetRef ref,
  BuildContext context, {
  StorefrontTab tab = StorefrontTab.account,
}) {
  ref.read(mainShellTabIndexProvider.notifier).goToTab(tab.shellIndex);
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
