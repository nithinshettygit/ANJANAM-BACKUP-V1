import 'package:ecommerce_app/features/order_history/domain/entities/order_payment.dart';
import 'package:flutter/material.dart';

/// Colored pill for payment status: green / orange / red.
class OrderPaymentStatusBadge extends StatelessWidget {
  final OrderPaymentStatus status;
  final bool compact;

  const OrderPaymentStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        status.displayLabel.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              fontSize: compact ? 10 : null,
            ),
      ),
    );
  }

  (Color bg, Color fg) _colors(BuildContext context) {
    switch (status) {
      case OrderPaymentStatus.paid:
        return (Colors.green.shade100, Colors.green.shade900);
      case OrderPaymentStatus.pending:
        return (Colors.orange.shade100, Colors.orange.shade900);
      case OrderPaymentStatus.failed:
        return (Theme.of(context).colorScheme.errorContainer,
            Theme.of(context).colorScheme.onErrorContainer);
    }
  }
}
