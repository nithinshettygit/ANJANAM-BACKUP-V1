import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/auth_redirect_config.dart';
import '../../admin/pages/admin_shell_page.dart';
import '../../admin/pages/order_details_page.dart';
import '../../admin/pages/user_details_page.dart';
import '../pages/backend_debug_page.dart';
import '../pages/catalog_page.dart';
import '../utils/storefront_category_slug.dart';
import '../pages/cart_page.dart';
import '../pages/checkout_page.dart';
import '../pages/customer_details_page.dart';
import '../pages/login_page.dart';
import '../pages/main_shell.dart';
import '../pages/more_page.dart';
import '../pages/music_page.dart';
import '../pages/order_details_page.dart';
import '../pages/order_history_page.dart';
import '../pages/order_success_page.dart';
import '../pages/profile_page.dart';
import '../pages/notifications_page.dart';
import '../pages/product_details_page.dart';
import '../../features/search/pages/product_search_page.dart';
import '../pages/email_confirmation_callback_page.dart';
import '../pages/signup_page.dart';
import '../pages/update_password_page.dart';
import '../pages/videos_page.dart';
import '../pages/wishlist_page.dart';
import '../pages/write_review_page.dart';
import '../pages/request_return_page.dart';
import 'auth_guard.dart';
import '../../features/order_history/domain/entities/order.dart';

/// Strips `?query` and a trailing `/` from route names (Flutter web passes `/auth/callback?code=...`).
String? _routePathOnly(String? name) {
  if (name == null || name.isEmpty) return name;
  final q = name.indexOf('?');
  var path = q < 0 ? name : name.substring(0, q);
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

/// Admin routes: no interactive edge-swipe-to-pop (avoids leaving admin accidentally on iOS/macOS).
class _AdminMaterialPageRoute<T> extends MaterialPageRoute<T> {
  _AdminMaterialPageRoute({
    required super.builder,
    super.settings,
  });

  @override
  bool get popGestureEnabled => false;
}

Route<dynamic>? _tryProductsRoute(RouteSettings settings) {
  final name = settings.name;
  if (name == null) return null;
  if (name != '/products' && !name.startsWith('/products?')) {
    return null;
  }
  String? category;
  if (name.contains('?')) {
    final uri = Uri.parse('http://x$name');
    final raw = uri.queryParameters['category'];
    if (raw != null && raw.trim().isNotEmpty) {
      category = raw.trim();
    }
  }
  final args = settings.arguments;
  if (category == null && args is Map) {
    final c = args['category'];
    if (c is String && c.trim().isNotEmpty) {
      category = c.trim();
    }
  }
  category = normalizeStorefrontCategorySlug(category);
  var title = 'Products';
  if (args is Map) {
    final t = args['title'];
    if (t is String && t.trim().isNotEmpty) {
      title = t.trim();
    }
  }
  return _customerRoute(CatalogPage(title: title, category: category));
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final productsRoute = _tryProductsRoute(settings);
    if (productsRoute != null) return productsRoute;
    final path = _routePathOnly(settings.name);
    // Shareable storefront URLs: {STOREFRONT_SHARE_BASE_URL}/product/<id> (default: anjanam-app.web.app)
    if (path != null && path.startsWith('/product/')) {
      final raw = path.substring('/product/'.length);
      final productId = Uri.decodeComponent(raw);
      if (productId.isNotEmpty) {
        // Public share URLs: do not wrap in [_AdminAwareCustomerRoute] — signed-in admins
        // on web would otherwise be sent to /admin and never see the product.
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ProductDetailsPage(productId: productId),
        );
      }
      return MaterialPageRoute(
        builder: (_) => const _RouteErrorPage(
          message: 'Missing product id for product link.',
        ),
      );
    }
    switch (path) {
      case '/':
      case null:
        return _customerRoute(const MainShell());
      case '/debug/backend':
        return MaterialPageRoute(builder: (_) => const BackendDebugPage());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupPage());
      // Email confirmation (PKCE). Supabase establishes session from `code` in the URL (web + App Links).
      case AuthRedirectConfig.webAuthCallbackPath:
      case AuthRedirectConfig.webCallbackPathLegacy:
        return _customerRoute(const EmailConfirmationCallbackPage());
      case AuthRedirectConfig.webAuthPasswordResetPath:
      case AuthRedirectConfig.webPasswordResetPathLegacy:
        return MaterialPageRoute(builder: (_) => const UpdatePasswordPage());
      case '/profile':
        return _authCustomerRoute(const ProfilePage());
      case '/customer-details':
        return _authCustomerRoute(const CustomerDetailsPage());
      case '/search':
        final searchArgs = settings.arguments;
        return _customerRoute(
          ProductSearchPage(
            initialQuery: searchArgs is String ? searchArgs : null,
          ),
        );
      case '/catalog':
        return _customerRoute(const CatalogPage());
      case '/books':
        return _customerRoute(
          const CatalogPage(
            title: 'Books',
            category: 'books',
          ),
        );
      case '/more':
        return _customerRoute(const MorePage());
      case '/videos':
        return _customerRoute(const VideosPage());
      case '/music':
        return _customerRoute(const MusicPage());
      case '/wishlist':
        return _customerRoute(const WishlistPage());
      case '/cart':
        return _authCustomerRoute(const CartPage());
      case '/checkout':
        String? buyNowProductId;
        var buyNowQuantity = 1;
        final checkoutArgs = settings.arguments;
        if (checkoutArgs is String) {
          buyNowProductId = checkoutArgs;
        } else if (checkoutArgs is Map) {
          final id = checkoutArgs['productId'];
          if (id is String && id.isNotEmpty) {
            buyNowProductId = id;
          }
          final q = checkoutArgs['quantity'];
          if (q is int && q > 0) {
            buyNowQuantity = q;
          } else if (q is num && q > 0) {
            buyNowQuantity = q.toInt();
          }
        }
        return _authCustomerRoute(
          CheckoutPage(
            buyNowProductId: buyNowProductId,
            buyNowQuantity: buyNowQuantity,
          ),
        );
      case '/orders':
        return _authCustomerRoute(const OrderHistoryPage());
      case '/order-details':
        final args = settings.arguments;
        final orderId = args is Order
            ? args.id
            : args is String
                ? args
                : null;
        if (orderId != null && orderId.isNotEmpty) {
          return MaterialPageRoute(
            builder: (_) => _AdminAwareCustomerRoute(
              child: OrderDetailsPage(orderId: orderId),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const _RouteErrorPage(
            message: 'Missing order details route arguments.',
          ),
        );
      case '/order-success':
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          final orderId = args['orderId'];
          final total = args['total'];
          final currency = args['currency'];
          if (orderId is String && total is num && currency is String) {
            final paymentId = args['razorpayPaymentId'];
            final showPaid = args['showOnlinePaymentConfirmed'] == true;
            return MaterialPageRoute(
              builder: (_) => _AdminAwareCustomerRoute(
                child: OrderSuccessPage(
                  orderId: orderId,
                  total: total.toDouble(),
                  currency: currency,
                  razorpayPaymentId:
                      paymentId is String && paymentId.isNotEmpty ? paymentId : null,
                  showOnlinePaymentConfirmed: showPaid,
                ),
              ),
            );
          }
        }
        return MaterialPageRoute(
          builder: (_) => const _RouteErrorPage(
            message: 'Missing order details for success route.',
          ),
        );
      case '/notifications':
        return _customerRoute(const NotificationsPage());
      case '/catalog/browse':
        final browseArgs = settings.arguments;
        if (browseArgs is Map) {
          final mode = browseArgs['mode']?.toString() ?? 'all';
          switch (mode) {
            case 'home_popular':
              return _customerRoute(
                const CatalogPage(
                  title: 'Popular Products',
                  popularOnly: true,
                ),
              );
            case 'home_recommended':
              return _customerRoute(
                const CatalogPage(
                  title: 'Recommended For You',
                  recommendedOnly: true,
                ),
              );
            case 'home_festival':
              return _customerRoute(
                const CatalogPage(
                  title: 'Festival Specials',
                  festivalSpecialOnly: true,
                ),
              );
            case 'home_new_arrivals':
              return _customerRoute(
                const CatalogPage(title: 'New Arrivals'),
              );
            case 'all':
            default:
              return _customerRoute(const CatalogPage());
          }
        }
        return _customerRoute(const CatalogPage());
      case '/catalog/details':
        final productId = settings.arguments;
        if (productId is String && productId.isNotEmpty) {
          return MaterialPageRoute(
            builder: (_) => _AdminAwareCustomerRoute(
              child: ProductDetailsPage(productId: productId),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const _RouteErrorPage(
            message: 'Missing product id for details route.',
          ),
        );
      case '/orders/request-return':
        final ra = settings.arguments;
        if (ra is RequestReturnPageArgs) {
          return _authCustomerRoute(RequestReturnPage(args: ra));
        }
        return MaterialPageRoute(
          builder: (_) => const _RouteErrorPage(
            message: 'Missing return request arguments.',
          ),
        );
      case '/reviews/write':
        final args = settings.arguments;
        String? productId;
        String? productTitle;
        if (args is Map) {
          final id = args['productId'];
          final title = args['productTitle'];
          if (id is String && id.isNotEmpty) productId = id;
          if (title is String && title.trim().isNotEmpty) {
            productTitle = title.trim();
          }
        } else if (args is String && args.isNotEmpty) {
          productId = args;
        }
        if (productId != null) {
          return _authCustomerRoute(
            WriteReviewPage(
              productId: productId,
              productTitle: productTitle,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const _RouteErrorPage(
            message: 'Missing product id for write review route.',
          ),
        );
      case '/admin':
      case '/admin/dashboard':
      case '/admin/products':
      case '/admin/product-qa':
      case '/admin/product-questions':
      case '/admin/orders':
      case '/admin/users':
      case '/admin/inventory':
      case '/admin/homepage':
      case '/admin/categories':
      case '/admin/notifications':
      case '/admin/returns':
      case '/admin/videos':
        return _AdminMaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AdminShellPage(currentRoute: settings.name ?? '/admin'),
        );
      case '/admin/orders/details':
        final orderId = settings.arguments;
        if (orderId is String && orderId.isNotEmpty) {
          return _AdminMaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AdminOrderDetailsPage(orderId: orderId),
          );
        }
        return _AdminMaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _RouteErrorPage(
            message: 'Missing order id for admin order details route.',
          ),
        );
      case '/admin/users/details':
        final userId = settings.arguments;
        if (userId is String && userId.isNotEmpty) {
          return _AdminMaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AdminUserDetailsPage(userId: userId),
          );
        }
        return _AdminMaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _RouteErrorPage(
            message: 'Missing user id for admin user details route.',
          ),
        );
      default:
        return _customerRoute(const MainShell());
    }
  }
}

Route<dynamic> _customerRoute(Widget child) {
  return MaterialPageRoute(
    builder: (_) => _AdminAwareCustomerRoute(child: child),
  );
}

Route<dynamic> _authCustomerRoute(Widget child) {
  return MaterialPageRoute(
    builder: (_) => AuthGuard(
      child: _AdminAwareCustomerRoute(child: child),
    ),
  );
}

class _AdminAwareCustomerRoute extends StatefulWidget {
  final Widget child;

  const _AdminAwareCustomerRoute({required this.child});

  @override
  State<_AdminAwareCustomerRoute> createState() => _AdminAwareCustomerRouteState();
}

class _AdminAwareCustomerRouteState extends State<_AdminAwareCustomerRoute> {
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role']?.toString().toLowerCase().trim();
      _isAdmin = role == 'admin' || role == 'super_admin';
    } catch (_) {
      _isAdmin = false;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (_isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/admin');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isAdmin) {
      return const Scaffold(
        body: SizedBox.shrink(),
      );
    }
    return widget.child;
  }
}

class _RouteErrorPage extends StatelessWidget {
  final String message;

  const _RouteErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message),
        ),
      ),
    );
  }
}

