import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/storefront_web_layout.dart';
import '../../core/layout/storefront_web_sidebar.dart';
import '../../features/addresses/state/user_addresses_provider.dart';
import '../../features/auth/state/auth_session_provider.dart';
import '../../features/cart/state/cart_controller.dart';
import '../../features/order_history/state/order_history_controller.dart';
import '../../features/wishlist/state/wishlist_provider.dart';
import '../../features/catalog/state/shop_categories_provider.dart';
import '../providers/customer_details_provider.dart';
import '../utils/main_shell_navigation.dart';
import 'explore_page.dart';
import 'home_page.dart';
import 'shop_categories_page.dart';
import 'order_history_page.dart';
import 'profile_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// Tabs at these indices require the user to be signed in.
  static const _authRequiredTabs = {3, 4}; // My Orders, Account
  bool _authListenAttached = false;

  static const List<Widget> _tabPages = [
    HomePage(),
    ShopCategoriesPage(),
    ExplorePage(),
    OrderHistoryPage(),
    ProfilePage(),
  ];

  Future<void> _onTabTapped(int index) async {
    final currentIndex = ref.read(mainShellTabIndexProvider);
    final isRetapOnActiveTab = currentIndex == index;

    if (_authRequiredTabs.contains(index)) {
      final user = ref.read(authSessionProvider).asData?.value;
      if (user == null) {
        if (!mounted) return;
        await Navigator.of(context).pushNamed('/login');
        return;
      }
    }

    ref.read(mainShellTabIndexProvider.notifier).goToTab(index);

    if (isRetapOnActiveTab) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      final tab = StorefrontTab.values.firstWhere(
        (value) => value.shellIndex == index,
        orElse: () => StorefrontTab.home,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        requestStorefrontScrollToTop(ref, tab);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authListenAttached) return;
    _authListenAttached = true;
    ref.listenManual<AsyncValue<dynamic>>(
      authSessionProvider,
      (previous, next) {
        final prevId = previous?.asData?.value?.id?.toString();
        final nextId = next.asData?.value?.id?.toString();
        if (prevId == nextId) return;

        // User identity changed (logout/login different account): refresh user-scoped data.
        ref.invalidate(cartControllerProvider);
        ref.invalidate(wishlistControllerProvider);
        ref.invalidate(orderHistoryControllerProvider);
        ref.read(orderHistorySearchQueryProvider.notifier).set('');
        ref.invalidate(userAddressesProvider);
        ref.invalidate(customerDetailsProvider);

        // If now signed out while on auth-only tab, move safely to Home.
        final currentTab = ref.read(mainShellTabIndexProvider);
        if (nextId == null && _authRequiredTabs.contains(currentTab)) {
          ref.read(mainShellTabIndexProvider.notifier).goToTab(0);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainShellTabIndexProvider);

    ref.listen<int>(mainShellTabIndexProvider, (previous, next) {
      if (next == StorefrontTab.categories.shellIndex) {
        ref.invalidate(shopCategoriesStorefrontProvider);
        ref.invalidate(catalogFilterCategoriesProvider);
      }
    });

    return PopScope(
      canPop: currentIndex == StorefrontTab.home.shellIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != StorefrontTab.home.shellIndex) {
          ref.read(mainShellTabIndexProvider.notifier).goToTab(
                StorefrontTab.home.shellIndex,
              );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showWebRail = kIsWeb &&
              constraints.maxWidth >= StorefrontBreakpoints.webNavigationRail;

          final stack = IndexedStack(
            index: currentIndex,
            children: _tabPages,
          );

          final Widget body;
          if (!kIsWeb) {
            body = stack;
          } else if (showWebRail) {
            body = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StorefrontWebSidebar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: _onTabTapped,
                ),
                Expanded(
                  child: WebMainContentPanel(child: stack),
                ),
              ],
            );
          } else {
            body = WebMaxWidthCenter(child: stack);
          }

          return Scaffold(
            body: body,
            bottomNavigationBar: showWebRail
                ? null
                : NavigationBar(
                    selectedIndex: currentIndex,
                    onDestinationSelected: _onTabTapped,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.storefront_outlined),
                        selectedIcon: Icon(Icons.storefront),
                        label: 'Shop',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.explore_outlined),
                        selectedIcon: Icon(Icons.explore),
                        label: 'Explore',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: 'My Orders',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'Account',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
