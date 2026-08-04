import 'package:ecommerce_app/admin/pages/order_details_page.dart';
import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/presentation/pages/order_details_page.dart';
import 'package:ecommerce_app/core/auth/blocked_account_gate.dart';
import 'package:ecommerce_app/presentation/pages/account_restricted_page.dart';
import 'package:ecommerce_app/presentation/widgets/error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

enum _InvoiceGateDecisionKind {
  notLoggedIn,
  unauthorized,
  orderNotFound,
  allowed,
  fallback,
}

class _InvoiceGateDecision {
  final _InvoiceGateDecisionKind kind;
  final bool isAdmin;

  const _InvoiceGateDecision({required this.kind, required this.isAdmin});

  const _InvoiceGateDecision.allowed({required this.isAdmin})
      : kind = _InvoiceGateDecisionKind.allowed;
  const _InvoiceGateDecision.notLoggedIn()
      : kind = _InvoiceGateDecisionKind.notLoggedIn,
        isAdmin = false;
  const _InvoiceGateDecision.unauthorized()
      : kind = _InvoiceGateDecisionKind.unauthorized,
        isAdmin = false;
  const _InvoiceGateDecision.orderNotFound()
      : kind = _InvoiceGateDecisionKind.orderNotFound,
        isAdmin = false;
  const _InvoiceGateDecision.fallback()
      : kind = _InvoiceGateDecisionKind.fallback,
        isAdmin = false;
}

/// Gate page for QR / deep links:
/// - Validates login status
/// - Validates order access (admin bypass)
/// - Only then renders the invoice/order details screen
class OrderInvoiceDeepLinkPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderInvoiceDeepLinkPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderInvoiceDeepLinkPage> createState() => _OrderInvoiceDeepLinkPageState();
}

class _OrderInvoiceDeepLinkPageState extends ConsumerState<OrderInvoiceDeepLinkPage> {
  String? _boundUserId;
  Future<_InvoiceGateDecision>? _gateFuture;

  Future<_InvoiceGateDecision> _loadGateDecision(String userId) async {
    final client = Supabase.instance.client;

    // Prevent showing order content to blocked users; this is consistent with
    // the rest of the app's behavior.
    await ensureUserIsNotBlocked(
      client,
      userId: userId,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );

    // Server-side access classification:
    // - Admins can access all invoices
    // - Normal users can only access their own orders
    //
    // Returns: { result: 'AUTHORIZED'|'UNAUTHORIZED'|'ORDER_NOT_FOUND', is_admin: bool }
    final rpcRes = await client.rpc(
      'check_order_invoice_access',
      params: {'p_order_id': widget.orderId},
    );

    if (rpcRes == null) return const _InvoiceGateDecision.fallback();

    final map = rpcRes is Map ? Map<String, dynamic>.from(rpcRes) : null;
    if (map == null) return const _InvoiceGateDecision.fallback();

    final result = map['result']?.toString();
    final isAdmin = map['is_admin'] == true ||
        map['is_admin']?.toString().toLowerCase().trim() == 'true';

    switch (result) {
      case 'AUTHORIZED':
        return _InvoiceGateDecision.allowed(isAdmin: isAdmin);
      case 'UNAUTHORIZED':
        return const _InvoiceGateDecision.unauthorized();
      case 'ORDER_NOT_FOUND':
        return const _InvoiceGateDecision.orderNotFound();
      case 'NOT_LOGGED_IN':
        return const _InvoiceGateDecision.notLoggedIn();
      default:
        return const _InvoiceGateDecision.fallback();
    }
  }

  Future<_InvoiceGateDecision> _getGateFuture(String userId) {
    if (_gateFuture != null && _boundUserId == userId) return _gateFuture!;
    _boundUserId = userId;
    _gateFuture = _loadGateDecision(userId);
    return _gateFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return session.when(
      data: (user) {
        if (user == null) {
          return ErrorScreen(
            title: 'Login required',
            message: 'Please login to view this invoice',
            icon: Icons.lock_outline,
            primaryButtonLabel: 'Login',
            onPrimaryButton: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          );
        }

        return FutureBuilder<_InvoiceGateDecision>(
          future: _getGateFuture(user.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              final err = snapshot.error;
              if (err is AuthException) {
                if (err.kind == AuthFailureKind.accountSuspended) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(blockedAccountGateProvider).presentRestricted(
                          message: err.message,
                        );
                  });
                  return AccountRestrictedPage(message: err.message);
                }
                return ErrorScreen(
                  title: 'Login required',
                  message: 'Please login to view this invoice',
                  icon: Icons.lock_outline,
                  primaryButtonLabel: 'Login',
                  onPrimaryButton: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                );
              }
              return const ErrorScreen(
                title: 'Error',
                message: 'Something went wrong. Please try again.',
                icon: Icons.error_outline,
              );
            }

            final decision = snapshot.data ?? const _InvoiceGateDecision.fallback();

            switch (decision.kind) {
              case _InvoiceGateDecisionKind.allowed:
                if (decision.isAdmin) {
                  return AdminOrderDetailsPage(orderId: widget.orderId);
                }
                return OrderDetailsPage(orderId: widget.orderId);
              case _InvoiceGateDecisionKind.notLoggedIn:
                return ErrorScreen(
                  title: 'Login required',
                  message: 'Please login to view this invoice',
                  icon: Icons.lock_outline,
                  primaryButtonLabel: 'Login',
                  onPrimaryButton: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                );
              case _InvoiceGateDecisionKind.unauthorized:
                return ErrorScreen(
                  title: 'Access denied',
                  message: 'This invoice does not belong to your account.',
                  icon: Icons.block,
                );
              case _InvoiceGateDecisionKind.orderNotFound:
                return ErrorScreen(
                  title: 'Invalid link',
                  message: 'Invalid or expired invoice link',
                  icon: Icons.link_off_outlined,
                );
              case _InvoiceGateDecisionKind.fallback:
                return ErrorScreen(
                  title: 'Error',
                  message: 'Something went wrong. Please try again.',
                  icon: Icons.error_outline,
                );
            }
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => ErrorScreen(
        title: 'Error',
        message: 'Something went wrong. Please try again.',
        icon: Icons.error_outline,
      ),
    );
  }
}

