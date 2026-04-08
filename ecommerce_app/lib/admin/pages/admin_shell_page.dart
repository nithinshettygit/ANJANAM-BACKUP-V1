import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/features/auth/data/auth_error_mapper.dart';
import 'package:ecommerce_app/features/auth/state/auth_actions_controller.dart';
import 'package:ecommerce_app/features/product_questions/pages/admin_product_qa_page.dart';
import 'package:ecommerce_app/features/reviews/pages/admin_product_reviews_page.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import '../widgets/admin_guard.dart';
import '../widgets/admin_shell_layout.dart';
import 'admin_categories_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_homepage_page.dart';
import 'admin_inventory_page.dart';
import 'admin_orders_page.dart';
import 'admin_notifications_page.dart';
import 'admin_alerts_page.dart';
import 'admin_returns_page.dart';
import 'admin_products_page.dart';
import 'admin_users_page.dart';
import 'admin_videos_page.dart';
import 'admin_articles_page.dart';
import 'admin_explore_suggestions_page.dart';

class AdminShellPage extends ConsumerWidget {
  final String currentRoute;

  const AdminShellPage({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGuard(
      child: AdminShellLayout(
        currentRoute: currentRoute,
        onLogout: () async {
          Future<void> attempt() async {
            try {
              await ref.read(authActionsProvider.notifier).signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            } catch (e) {
              if (!context.mounted) return;
              await presentAuthIssue(
                context,
                flow: AuthIssueFlow.signOut,
                error: resolvePresentableAuthError(e, isSignUp: false),
                onRetry: () {
                  attempt();
                },
              );
            }
          }

          await attempt();
        },
        body: _bodyForRoute(),
      ),
    );
  }

  Widget _bodyForRoute() {
    switch (currentRoute) {
      case '/admin/products':
        return const AdminProductsPage();
      case '/admin/product-qa':
      case '/admin/product-questions':
        return const AdminProductQaPage();
      case '/admin/product-reviews':
        return const AdminProductReviewsPage();
      case '/admin/orders':
        return const AdminOrdersPage();
      case '/admin/users':
        return const AdminUsersPage();
      case '/admin/inventory':
        return const AdminInventoryPage();
      case '/admin/homepage':
        return const AdminHomepagePage();
      case '/admin/videos':
        return const AdminVideosPage();
      case '/admin/articles':
        return const AdminArticlesPage();
      case '/admin/explore-suggestions':
        return const AdminExploreSuggestionsPage();
      case '/admin/categories':
        return const AdminCategoriesPage();
      case '/admin/notifications':
        return const AdminNotificationsPage();
      case '/admin/admin-notifications':
        return const AdminAlertsPage();
      case '/admin/returns':
        return const AdminReturnsPage();
      case '/admin':
      default:
        return const AdminDashboardPage();
    }
  }
}
