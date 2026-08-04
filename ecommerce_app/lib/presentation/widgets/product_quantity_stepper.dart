import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Standard +/- control for product quantity (cards, details, cart-style rows).
class ProductQuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final int minQuantity;
  final int maxQuantity;
  final bool dense;
  final bool compact;
  final bool enabled;
  /// When true, tapping minus at [minQuantity] calls [onChanged](0) (e.g. remove line).
  final bool allowZeroOnDecrement;

  const ProductQuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.minQuantity = 1,
    this.maxQuantity = 99,
    this.dense = false,
    this.compact = false,
    this.enabled = true,
    this.allowZeroOnDecrement = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = compact ? 28.0 : (dense ? 32.0 : 40.0);
    final iconSize = compact ? 16.0 : (dense ? 18.0 : 22.0);
    final canDec = enabled &&
        (quantity > minQuantity || (allowZeroOnDecrement && quantity <= minQuantity && quantity >= 1));
    final canInc = enabled && quantity < maxQuantity;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(h / 2),
      child: SizedBox(
        height: h,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: h,
              height: h,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: !canDec
                    ? null
                    : () {
                        if (allowZeroOnDecrement && quantity <= minQuantity) {
                          onChanged(0);
                        } else {
                          onChanged((quantity - 1).clamp(minQuantity, maxQuantity));
                        }
                      },
                icon: Icon(Icons.remove, size: iconSize),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: compact ? 24 : (dense ? 28 : 36),
              ),
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoalBlack,
                    ),
              ),
            ),
            SizedBox(
              width: h,
              height: h,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: !canInc
                    ? null
                    : () => onChanged((quantity + 1).clamp(minQuantity, maxQuantity)),
                icon: Icon(Icons.add, size: iconSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
