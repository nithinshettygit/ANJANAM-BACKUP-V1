import 'dart:async';

import 'package:ecommerce_app/core/payments/razorpay_service.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/addresses/domain/entities/user_address.dart';
import 'package:ecommerce_app/features/addresses/state/user_addresses_provider.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/cart/domain/entities/cart_item.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/checkout/domain/checkout_pricing_rules.dart';
import 'package:ecommerce_app/features/checkout/domain/shipping_details.dart';
import 'package:ecommerce_app/features/checkout/state/checkout_actions_controller.dart';
import 'package:ecommerce_app/features/checkout/state/checkout_pricing_provider.dart';
import 'package:ecommerce_app/features/checkout/state/order_payment_provider.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/product_details/state/product_details_providers.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/product_availability.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _CheckoutPaymentMethod {
  razorpay,
  cod,
}

enum _CheckoutPhase {
  idle,
  processingOrder,
  openingPayment,
  confirmingPayment,
  showingPaymentSuccess,
  showingPaymentFailed,
}

class CheckoutPage extends ConsumerStatefulWidget {
  final String? buyNowProductId;
  final int buyNowQuantity;

  const CheckoutPage({
    super.key,
    this.buyNowProductId,
    this.buyNowQuantity = 1,
  });

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  String? _selectedAddressId;
  bool _saveNewAddress = true;
  bool _checkoutUiSeeded = false;
  bool _showNewAddressForm = false;
  /// Prevents double submit (duplicate orders) for the whole checkout + payment flow.
  bool _checkoutFlowLock = false;
  _CheckoutPaymentMethod _paymentMethod = _CheckoutPaymentMethod.razorpay;
  _CheckoutPhase _checkoutPhase = _CheckoutPhase.idle;
  String? _paymentFailureOverlayDetail;
  bool _successOverlayIsCod = false;
  RazorpayService? _razorpayService;

  @override
  void dispose() {
    _razorpayService?.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  void _fillFromAddress(UserAddress a) {
    _nameCtrl.text = a.fullName;
    _phoneCtrl.text = a.phone;
    _addressCtrl.text = a.addressLine;
    _cityCtrl.text = a.city;
    _postalCtrl.text = a.postalCode;
  }

  void _clearForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _cityCtrl.clear();
    _postalCtrl.clear();
  }

  ShippingDetails? _shippingFromSelection(List<UserAddress> saved) {
    if (_selectedAddressId != null && !_showNewAddressForm) {
      for (final a in saved) {
        if (a.id == _selectedAddressId) return a.toShippingDetails();
      }
    }
    if (_showNewAddressForm || saved.isEmpty) {
      final s = ShippingDetails(
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        addressLine: _addressCtrl.text,
        city: _cityCtrl.text,
        postalCode: _postalCtrl.text,
      );
      if (s.validationError() != null) return null;
      return s;
    }
    return null;
  }

  void _maybeSeedCheckoutUi(List<UserAddress> saved) {
    if (_checkoutUiSeeded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _checkoutUiSeeded) return;
      _checkoutUiSeeded = true;
      setState(() {
        if (saved.isEmpty) {
          _showNewAddressForm = true;
          _selectedAddressId = null;
        } else {
          UserAddress? d;
          for (final a in saved) {
            if (a.isDefault) {
              d = a;
              break;
            }
          }
          d ??= saved.first;
          _selectedAddressId = d.id;
          _showNewAddressForm = false;
          _fillFromAddress(d);
        }
      });
    });
  }

  bool _canPlaceOrder({
    required List<CartItem> items,
    required List<UserAddress> saved,
    required bool pricingReady,
  }) {
    if (items.isEmpty || !pricingReady) return false;
    final ship = _shippingFromSelection(saved);
    return ship != null;
  }

  void _refreshCachesAfterOrder(Order order) {
    ref.invalidate(cartControllerProvider);
    for (final line in order.items) {
      ref.invalidate(productDetailsProvider(line.productId));
    }
    ref.invalidate(productListProvider(ProductListQuery(limit: 30, offset: 0)));
    ref.invalidate(productListProvider(ProductListQuery(limit: 50, offset: 0)));
    ref.invalidate(productListProvider(ProductListQuery(limit: 200, offset: 0)));
  }

  void _navigateOrderSuccess(Order order, {String? razorpayPaymentId}) {
    Navigator.of(context).pushReplacementNamed(
      '/order-success',
      arguments: <String, dynamic>{
        'orderId': order.id,
        'total': order.grandTotal,
        'currency': order.currency,
        if (razorpayPaymentId != null && razorpayPaymentId.isNotEmpty)
          'razorpayPaymentId': razorpayPaymentId,
        'showOnlinePaymentConfirmed':
            razorpayPaymentId != null && razorpayPaymentId.isNotEmpty,
      },
    );
  }

  void _releaseCheckoutLock() {
    _checkoutFlowLock = false;
  }

  String _placeOrderButtonLabel() {
    if (!_checkoutFlowLock) {
      return 'Place order';
    }
    switch (_checkoutPhase) {
      case _CheckoutPhase.idle:
        return 'Waiting for payment…';
      case _CheckoutPhase.processingOrder:
        return 'Processing order…';
      case _CheckoutPhase.openingPayment:
        return 'Opening payment…';
      case _CheckoutPhase.confirmingPayment:
        return 'Confirming payment…';
      case _CheckoutPhase.showingPaymentSuccess:
        return 'Payment success';
      case _CheckoutPhase.showingPaymentFailed:
        return 'Payment failed';
    }
  }

  Future<void> _placeOrder({
    required List<CartItem> items,
    required List<UserAddress> saved,
  }) async {
    if (_checkoutFlowLock) return;

    final useForm =
        _showNewAddressForm || saved.isEmpty || _selectedAddressId == null;

    final ship = _shippingFromSelection(saved);
    if (ship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a valid delivery address.'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    if (useForm && _formKey.currentState?.validate() != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted address fields.'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    _checkoutFlowLock = true;
    setState(() {
      _checkoutPhase = _CheckoutPhase.processingOrder;
      _paymentFailureOverlayDetail = null;
    });

    late final Order order;
    try {
      if (useForm && _saveNewAddress && saved.length < 20) {
        try {
          await ref.read(userAddressRepositoryProvider).createAddress(
                fullName: ship.fullName,
                phone: ship.phone,
                addressLine: ship.addressLine,
                city: ship.city,
                postalCode: ship.postalCode,
                isDefault: saved.isEmpty,
              );
          ref.invalidate(userAddressesProvider);
        } catch (_) {
          // Non-blocking: order still proceeds
        }
      }

      order = await ref.read(checkoutActionsProvider.notifier).placeOrder(
            shipping: ship,
            buyNowProductId: widget.buyNowProductId,
            buyNowQuantity: widget.buyNowQuantity,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _checkoutPhase = _CheckoutPhase.idle);
        _releaseCheckoutLock();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text('Checkout failed: $e'),
          ),
        );
      } else {
        _releaseCheckoutLock();
      }
      return;
    }

    if (!mounted) {
      _releaseCheckoutLock();
      return;
    }

    _refreshCachesAfterOrder(order);

    final paymentSvc = ref.read(orderPaymentServiceProvider);

    // Cash on delivery: no Razorpay; persist method and show success.
    if (_paymentMethod == _CheckoutPaymentMethod.cod) {
      setState(() => _checkoutPhase = _CheckoutPhase.confirmingPayment);
      try {
        await paymentSvc.setOrderPaymentCod(orderId: order.id);
      } catch (e) {
        if (mounted) {
          setState(() => _checkoutPhase = _CheckoutPhase.idle);
          _releaseCheckoutLock();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.fixed,
              content: Text('Order was created but COD could not be saved: $e'),
            ),
          );
        } else {
          _releaseCheckoutLock();
        }
        return;
      }
      if (!mounted) {
        _releaseCheckoutLock();
        return;
      }
      setState(() {
        _successOverlayIsCod = true;
        _checkoutPhase = _CheckoutPhase.showingPaymentSuccess;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) {
        _releaseCheckoutLock();
        return;
      }
      _releaseCheckoutLock();
      setState(() => _checkoutPhase = _CheckoutPhase.idle);
      _navigateOrderSuccess(order);
      return;
    }

    // Razorpay (online) — mobile uses razorpay_flutter; web uses Checkout.js.
    final env = ref.read(appEnvProvider);
    final canOpenRazorpay = env.razorpayKeyId.isNotEmpty;

    if (!canOpenRazorpay) {
      if (mounted) {
        setState(() => _checkoutPhase = _CheckoutPhase.idle);
        _releaseCheckoutLock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(
              'Razorpay is not configured. Add RAZORPAY_KEY_ID '
              'at build time, or choose Cash on Delivery.',
            ),
          ),
        );
        _navigateOrderSuccess(order);
      } else {
        _releaseCheckoutLock();
      }
      return;
    }

    _razorpayService ??= RazorpayService(keyId: env.razorpayKeyId);
    final userEmail = ref.read(authSessionProvider).maybeWhen(
          data: (u) => u == null ? '' : u.email.trim(),
          orElse: () => '',
        );
    final completer = Completer<void>();

    setState(() => _checkoutPhase = _CheckoutPhase.openingPayment);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) {
      _releaseCheckoutLock();
      if (!completer.isCompleted) completer.complete();
      return;
    }

    String? rzpCheckoutOrderId;
    try {
      rzpCheckoutOrderId = await paymentSvc.tryCreateRazorpayServerOrder(orderId: order.id);
      if (rzpCheckoutOrderId != null) {
        try {
          await paymentSvc.setRazorpayCheckoutOrderId(
            orderId: order.id,
            razorpayOrderId: rzpCheckoutOrderId,
          );
        } catch (_) {
          // e.g. migration `set_razorpay_checkout_order_id` not applied — checkout still works.
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkoutPhase = _CheckoutPhase.idle);
        _releaseCheckoutLock();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text('Could not open payment: $e'),
          ),
        );
      } else {
        _releaseCheckoutLock();
      }
      if (!completer.isCompleted) completer.complete();
      return;
    }

    _razorpayService!.openCheckout(
      amountPaise: (order.grandTotal * 100).round(),
      customerName: ship.fullName,
      customerEmail: userEmail,
      customerContact: ship.phone,
      razorpayOrderId: rzpCheckoutOrderId,
      onPaymentSuccess: (paymentId, razorpayOrderId, razorpaySignature) async {
        if (!mounted) return;
        setState(() => _checkoutPhase = _CheckoutPhase.confirmingPayment);
        try {
          await paymentSvc.verifyRazorpayPaymentAndMarkPaid(
            orderId: order.id,
            razorpayPaymentId: paymentId,
            razorpayOrderId: razorpayOrderId,
            razorpaySignature: razorpaySignature,
          );
          if (!mounted) return;
          setState(() {
            _successOverlayIsCod = false;
            _checkoutPhase = _CheckoutPhase.showingPaymentSuccess;
          });
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          _releaseCheckoutLock();
          setState(() => _checkoutPhase = _CheckoutPhase.idle);
          _navigateOrderSuccess(order, razorpayPaymentId: paymentId);
        } catch (e) {
          if (mounted) {
            setState(() => _checkoutPhase = _CheckoutPhase.idle);
            _releaseCheckoutLock();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.fixed,
                content: Text(
                  'Payment went through but we could not update your order. '
                  'Save this reference for support: $paymentId. Details: $e',
                ),
              ),
            );
            Navigator.of(context).pushReplacementNamed('/orders');
          } else {
            _releaseCheckoutLock();
          }
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      onPaymentError: (message) async {
        if (!mounted) return;
        setState(() => _checkoutPhase = _CheckoutPhase.confirmingPayment);
        try {
          await paymentSvc.updatePaymentStatus(
            orderId: order.id,
            paymentStatus: 'failed',
          );
        } catch (_) {
          // Order may stay pending; UI still shows failure.
        }
        if (!mounted) return;
        setState(() {
          _paymentFailureOverlayDetail = message;
          _checkoutPhase = _CheckoutPhase.showingPaymentFailed;
        });
        await Future<void>.delayed(const Duration(milliseconds: 750));
        if (!mounted) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        setState(() => _checkoutPhase = _CheckoutPhase.idle);
        _releaseCheckoutLock();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: const Text('Payment failed. Please try again.'),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/orders');
        if (!completer.isCompleted) completer.complete();
      },
      onExternalWallet: (_) {},
    );

    // Clear "opening" only if Razorpay did not already advance the phase (e.g. sync validation error).
    if (mounted && _checkoutPhase == _CheckoutPhase.openingPayment) {
      setState(() => _checkoutPhase = _CheckoutPhase.idle);
    }

    await completer.future;
  }

  Widget _checkoutLoadingOverlay(BuildContext context) {
    final p = _checkoutPhase;
    if (p == _CheckoutPhase.idle) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final showSpinner = p == _CheckoutPhase.processingOrder ||
        p == _CheckoutPhase.openingPayment ||
        p == _CheckoutPhase.confirmingPayment;

    String title;
    switch (p) {
      case _CheckoutPhase.idle:
        title = '';
      case _CheckoutPhase.processingOrder:
        title = 'Processing order…';
      case _CheckoutPhase.openingPayment:
        title = 'Opening payment…';
      case _CheckoutPhase.confirmingPayment:
        title = 'Confirming payment…';
      case _CheckoutPhase.showingPaymentSuccess:
        title = _successOverlayIsCod ? 'Order placed!' : 'Payment successful!';
      case _CheckoutPhase.showingPaymentFailed:
        title = 'Payment failed';
    }

    return Positioned.fill(
      child: AbsorbPointer(
        child: Material(
          color: Colors.black.withOpacity(0.45),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSpinner) ...[
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (p == _CheckoutPhase.showingPaymentSuccess)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 52,
                          color: scheme.primary,
                        ),
                      if (p == _CheckoutPhase.showingPaymentFailed)
                        Icon(
                          Icons.error_outline_rounded,
                          size: 52,
                          color: scheme.error,
                        ),
                      if (p == _CheckoutPhase.showingPaymentSuccess ||
                          p == _CheckoutPhase.showingPaymentFailed)
                        const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (p == _CheckoutPhase.showingPaymentFailed &&
                          _paymentFailureOverlayDetail != null &&
                          _paymentFailureOverlayDetail!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _paymentFailureOverlayDetail!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapWithCheckoutOverlay({required PreferredSizeWidget? appBar, required Widget body}) {
    return Stack(
      children: [
        Scaffold(appBar: appBar, body: body),
        _checkoutLoadingOverlay(context),
      ],
    );
  }

  Future<void> _openAddressEditor(UserAddress a) async {
    final repo = ref.read(userAddressRepositoryProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddressEditorDialog(
        title: 'Edit address',
        initialName: a.fullName,
        initialPhone: a.phone,
        initialAddress: a.addressLine,
        initialCity: a.city,
        initialPostal: a.postalCode,
        showDefaultToggle: true,
        initialDefault: a.isDefault,
        onSave: (name, phone, addr, city, pin, isDefault) async {
          await repo.updateAddress(
            id: a.id,
            fullName: name,
            phone: phone,
            addressLine: addr,
            city: city,
            postalCode: pin,
            isDefault: isDefault,
          );
        },
      ),
    );
    if (ok == true && mounted) {
      ref.invalidate(userAddressesProvider);
    }
  }

  Future<void> _deleteAddress(UserAddress a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text('Remove delivery address for ${a.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(userAddressRepositoryProvider).deleteAddress(a.id);
    if (!mounted) return;
    if (_selectedAddressId == a.id) {
      setState(() {
        _selectedAddressId = null;
        _clearForm();
        _showNewAddressForm = true;
      });
    }
    ref.invalidate(userAddressesProvider);
  }

  Future<void> _markDefault(UserAddress a) async {
    await ref.read(userAddressRepositoryProvider).setDefaultAddress(a.id);
    if (mounted) ref.invalidate(userAddressesProvider);
  }

  Widget _addressSection(List<UserAddress> saved) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery address',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (saved.isNotEmpty) ...[
              Text(
                'Saved addresses',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...saved.map((a) {
                final selected = _selectedAddressId == a.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAddressId = a.id;
                        _showNewAddressForm = false;
                        _fillFromAddress(a);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25)
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected ? Theme.of(context).colorScheme.primary : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    if (a.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('DEFAULT', style: TextStyle(fontSize: 10)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${a.phone} · PIN ${a.postalCode}'),
                                Text('${a.addressLine}, ${a.city}'),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _openAddressEditor(a);
                              if (v == 'del') _deleteAddress(a);
                              if (v == 'def') _markDefault(a);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'def', child: Text('Set as default')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'del', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedAddressId = null;
                  _showNewAddressForm = true;
                  _clearForm();
                });
              },
              icon: const Icon(Icons.add),
              label: Text(saved.isEmpty ? 'Enter delivery address' : 'Add new address'),
            ),
            if (_showNewAddressForm || saved.isEmpty) ...[
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().length < 2) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone number (10 digits)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (!ShippingDetails.isValidIndianPhone(v ?? '')) {
                          return 'Enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'House / Street / Area',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) {
                        if (v == null || v.trim().length < 3) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().length < 2) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PIN code (6 digits)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (!ShippingDetails.isValidIndianPostal(v ?? '')) {
                          return 'Enter a valid 6-digit PIN';
                        }
                        return null;
                      },
                    ),
                    if (_showNewAddressForm || saved.isEmpty) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Save this address for future orders'),
                        value: _saveNewAddress,
                        onChanged: (v) => setState(() => _saveNewAddress = v ?? true),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryPanel({
    required List<CartItem> items,
    required CheckoutPricingRules pricing,
    required String accountEmail,
    required List<UserAddress> saved,
    String? buyNowHint,
  }) {
    final subtotal = items.fold<double>(0, (s, e) => s + e.lineTotal);
    final delivery = pricing.deliveryForSubtotal(subtotal);
    const discount = 0.0;
    final total = subtotal + delivery;
    final canPlace = _canPlaceOrder(items: items, saved: saved, pricingReady: true) &&
        !_checkoutFlowLock;
    final paymentLocked = _checkoutFlowLock;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (buyNowHint != null) ...[
              const SizedBox(height: 6),
              Text(
                buyNowHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              accountEmail,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text('Items (${items.length})', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '× ${e.quantity}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatRupee(e.lineTotal),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.priceText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            _priceRow(
              'Subtotal',
              formatRupee(subtotal),
              valueStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.priceText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            _priceRow(
              'Delivery',
              delivery <= 0
                  ? 'FREE'
                  : formatRupee(delivery),
              valueStyle: delivery <= 0
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    )
                  : Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.priceText,
                        fontWeight: FontWeight.w600,
                      ),
            ),
            _priceRow(
              'Discount',
              discount > 0 ? '- ${formatRupee(discount)}' : '—',
              valueStyle: discount > 0
                  ? Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.priceText,
                        fontWeight: FontWeight.w600,
                      )
                  : Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            _priceRow(
              'Total payable',
              formatRupee(total),
              emphasize: true,
              valueStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.priceText,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment method',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            RadioListTile<_CheckoutPaymentMethod>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Razorpay'),
              subtitle: const Text('Card, UPI, net banking, wallets'),
              value: _CheckoutPaymentMethod.razorpay,
              groupValue: _paymentMethod,
              onChanged: paymentLocked
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _paymentMethod = v);
                    },
            ),
            RadioListTile<_CheckoutPaymentMethod>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cash on Delivery'),
              subtitle: const Text('Pay when your order arrives'),
              value: _CheckoutPaymentMethod.cod,
              groupValue: _paymentMethod,
              onChanged: paymentLocked
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _paymentMethod = v);
                    },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canPlace
                    ? () => _placeOrder(items: items, saved: saved)
                    : null,
                child: Text(_placeOrderButtonLabel()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {TextStyle? valueStyle, bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize
                ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                : null,
          ),
          Text(
            value,
            style: valueStyle ??
                (emphasize
                    ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
                    : null),
          ),
        ],
      ),
    );
  }

  Widget _checkoutBody({
    required List<CartItem> items,
    required String accountEmail,
    String? buyNowHint,
  }) {
    final addressesAsync = ref.watch(userAddressesProvider);
    final pricingAsync = ref.watch(checkoutPricingRulesProvider);

    return addressesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => PageErrorState(
        message: 'Could not load addresses: $e',
        onRetry: () => ref.invalidate(userAddressesProvider),
      ),
      data: (saved) {
        _maybeSeedCheckoutUi(saved);

        return pricingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildLayout(
            items: items,
            saved: saved,
            pricing: CheckoutPricingRules.fallback,
            accountEmail: accountEmail,
            buyNowHint: buyNowHint,
          ),
          data: (pricing) => _buildLayout(
            items: items,
            saved: saved,
            pricing: pricing,
            accountEmail: accountEmail,
            buyNowHint: buyNowHint,
          ),
        );
      },
    );
  }

  Widget _buildLayout({
    required List<CartItem> items,
    required List<UserAddress> saved,
    required CheckoutPricingRules pricing,
    required String accountEmail,
    String? buyNowHint,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final address = _addressSection(saved);
        final summary = _summaryPanel(
          items: items,
          pricing: pricing,
          accountEmail: accountEmail,
          saved: saved,
          buyNowHint: buyNowHint,
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: address,
                ),
              ),
              Expanded(
                flex: 9,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: summary,
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              address,
              const SizedBox(height: 16),
              summary,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyNowId = widget.buyNowProductId;
    final accountEmail = ref.watch(authSessionProvider).when(
          data: (user) => user?.email ?? 'Not signed in',
          loading: () => 'Loading…',
          error: (_, __) => 'Unavailable',
        );

    if (buyNowId == null) {
      final cartAsync = ref.watch(cartControllerProvider);
      return _wrapWithCheckoutOverlay(
        appBar: AppBar(title: const Text('Checkout')),
        body: cartAsync.when(
          data: (cart) {
            if (cart.items.isEmpty) {
              return const PageEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'No items to checkout',
                subtitle: 'Add items to your cart before placing an order.',
              );
            }
            return _checkoutBody(items: cart.items, accountEmail: accountEmail);
          },
          loading: () => const PageLoading(message: 'Preparing checkout…'),
          error: (e, _) => PageErrorState(
            message: 'Failed to load cart: $e',
            onRetry: () => ref.invalidate(cartControllerProvider),
          ),
        ),
      );
    }

    final cartAsync = ref.watch(cartControllerProvider);
    return _wrapWithCheckoutOverlay(
      appBar: AppBar(title: const Text('Buy now')),
      body: cartAsync.when(
        data: (cart) {
          final fromCart = cart.items.where((e) => e.productId == buyNowId).toList();
          if (fromCart.isNotEmpty) {
            return _checkoutBody(
              items: fromCart,
              accountEmail: accountEmail,
              buyNowHint: 'From your cart (${fromCart.length} line(s))',
            );
          }

          final detailAsync = ref.watch(productDetailsProvider(buyNowId));
          return detailAsync.when(
            data: (detail) {
              final p = detail.product;
              final maxQ = maxSelectableQuantity(p);
              final q = widget.buyNowQuantity.clamp(1, maxQ);
              final synthetic = CartItem(
                productId: p.id,
                title: p.title,
                imageUrls: p.imageUrls,
                unitPrice: p.price,
                currency: p.currency,
                quantity: q,
              );
              return _checkoutBody(
                items: [synthetic],
                accountEmail: accountEmail,
                buyNowHint: 'Direct checkout — cart unchanged unless you add items there.',
              );
            },
            loading: () => const PageLoading(message: 'Loading product…'),
            error: (e, _) => PageErrorState(
              message: 'Could not load product: $e',
              onRetry: () => ref.invalidate(productDetailsProvider(buyNowId)),
            ),
          );
        },
        loading: () => const PageLoading(message: 'Preparing checkout…'),
        error: (e, _) => PageErrorState(
          message: 'Failed to load checkout: $e',
          onRetry: () => ref.invalidate(cartControllerProvider),
        ),
      ),
    );
  }
}

class _AddressEditorDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialPhone;
  final String initialAddress;
  final String initialCity;
  final String initialPostal;
  final bool showDefaultToggle;
  final bool initialDefault;
  final Future<void> Function(
    String name,
    String phone,
    String addr,
    String city,
    String pin,
    bool isDefault,
  ) onSave;

  const _AddressEditorDialog({
    required this.title,
    required this.initialName,
    required this.initialPhone,
    required this.initialAddress,
    required this.initialCity,
    required this.initialPostal,
    required this.showDefaultToggle,
    required this.initialDefault,
    required this.onSave,
  });

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _addr;
  late final TextEditingController _city;
  late final TextEditingController _postal;
  late bool _isDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _phone = TextEditingController(text: widget.initialPhone);
    _addr = TextEditingController(text: widget.initialAddress);
    _city = TextEditingController(text: widget.initialCity);
    _postal = TextEditingController(text: widget.initialPostal);
    _isDefault = widget.initialDefault;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    _city.dispose();
    _postal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    !ShippingDetails.isValidIndianPhone(v ?? '') ? '10 digits' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addr,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().length < 3) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _postal,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    !ShippingDetails.isValidIndianPostal(v ?? '') ? '6 digits' : null,
              ),
              if (widget.showDefaultToggle) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Default address'),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v ?? false),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (_formKey.currentState?.validate() != true) return;
                  setState(() => _saving = true);
                  try {
                    await widget.onSave(
                      _name.text,
                      _phone.text,
                      _addr.text,
                      _city.text,
                      _postal.text,
                      _isDefault,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
