import 'package:flutter/material.dart';

import '../../features/order_history/domain/entities/order_status.dart';
import '../../l10n/app_localizations.dart';

/// Fulfilment status pill: colors, optional compact label, single-line ellipsis for list layouts.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    super.key,
    required this.status,
    this.compact = false,
    this.uppercase = false,
  });

  final OrderStatus status;

  /// Uses [OrderStatusX.compactDisplayLabel] when true (narrow rows).
  final bool compact;

  /// When true, label is shown in uppercase (e.g. order details header).
  final bool uppercase;

  String _label(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final base = switch (status) {
      OrderStatus.pendingPayment => localizations.pendingPayment,
      OrderStatus.paymentFailed => localizations.paymentFailedStatus,
      OrderStatus.processing => localizations.processing,
      OrderStatus.packed => localizations.packed,
      OrderStatus.shipped => localizations.shipped,
      OrderStatus.outForDelivery => localizations.outForDelivery,
      OrderStatus.delivered => localizations.delivered,
      OrderStatus.cancelRequested => compact
          ? localizations.cancelPending
          : localizations.cancellationPending,
      OrderStatus.cancelled => localizations.cancelled,
    };
    return uppercase ? base.toUpperCase() : base;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = _fulfillmentColors(scheme, status);
    final textStyle = (compact
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(
      color: fg,
      fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
      letterSpacing: uppercase ? 0.35 : null,
    );

    return SizedBox(
      width: double.infinity,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Text(
          _label(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          softWrap: false,
          style: textStyle,
        ),
      ),
    );
  }

  (Color bg, Color fg) _fulfillmentColors(
      ColorScheme scheme, OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingPayment:
        return (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
      case OrderStatus.paymentFailed:
        return (Colors.red.shade50, Colors.red.shade900);
      case OrderStatus.packed:
        return (Colors.amber.shade50, Colors.amber.shade900);
      case OrderStatus.outForDelivery:
        return (Colors.lightBlue.shade50, Colors.lightBlue.shade900);
      case OrderStatus.processing:
        return (Colors.orange.shade100, Colors.orange.shade900);
      case OrderStatus.shipped:
        return (Colors.blue.shade50, Colors.blue.shade800);
      case OrderStatus.delivered:
        return (Colors.green.shade100, Colors.green.shade900);
      case OrderStatus.cancelRequested:
        return (scheme.secondaryContainer, scheme.onSecondaryContainer);
      case OrderStatus.cancelled:
        return (scheme.errorContainer, scheme.onErrorContainer);
    }
  }
}
