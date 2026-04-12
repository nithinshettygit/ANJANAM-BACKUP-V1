import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/articles/pages/article_detail_page.dart';
import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:ecommerce_app/presentation/utils/order_history_format.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/widgets/order_payment_status_badge.dart';
import 'package:ecommerce_app/presentation/widgets/order_status_chip.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single order summary: image left, details center, status badge right; actions row below.
class OrderHistoryOrderCard extends ConsumerWidget {
  final Order order;

  const OrderHistoryOrderCard({super.key, required this.order});

  static const double _imageSize = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final primary = _primaryLine(order);
    final imageUrl = primary.imageUrls.isNotEmpty ? primary.imageUrls.first : null;
    final totalQty = order.items.fold<int>(0, (s, e) => s + e.quantity);
    final moreCount = order.items.length > 1 ? order.items.length - 1 : 0;
    final canOpenProduct = primary.productId.isNotEmpty;
    final cancelled = order.status == OrderStatus.cancelled;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: canOpenProduct
                ? () async {
                    final articleId = await ref
                        .read(articlesSupabaseServiceProvider)
                        .findArticleIdByCheckoutProductId(primary.productId);
                    if (!context.mounted) return;
                    if (articleId != null && articleId.isNotEmpty) {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailPage(articleId: articleId),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pushNamed(
                      '/catalog/details',
                      arguments: primary.productId,
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, rowConstraints) {
                  final badgeColumnWidth = (rowConstraints.maxWidth * 0.42).clamp(118.0, 168.0);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppNetworkImage(
                        imageUrl: imageUrl,
                        width: _imageSize,
                        height: _imageSize,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              primary.title.isNotEmpty ? primary.title : 'Order item',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order #${formatOrderIdDisplay(order.id)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            if (moreCount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '+$moreCount more ${moreCount == 1 ? 'item' : 'items'}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Order date: ${formatShortOrderDate(order.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty: $totalQty · ${formatRupee(order.grandTotal)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.priceText,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: badgeColumnWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OrderStatusChip(status: order.status, compact: true),
                            const SizedBox(height: 6),
                            OrderPaymentStatusBadge(status: order.paymentStatus, compact: true),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/order-details',
                    arguments: order.id,
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View order details'),
                ),
                if (!cancelled && canOpenProduct)
                  TextButton.icon(
                    onPressed: () => _buyAgain(context, ref, primary),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Buy again'),
                  ),
                if (order.status == OrderStatus.delivered && canOpenProduct)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(
                      '/reviews/write',
                      arguments: {
                        'productId': primary.productId,
                        'productTitle': primary.title,
                      },
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Write review'),
                  ),
                if (order.status == OrderStatus.shipped ||
                    order.status == OrderStatus.outForDelivery)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(
                      '/order-details',
                      arguments: order.id,
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('Track order'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OrderItem _primaryLine(Order order) {
    if (order.items.isEmpty) {
      return OrderItem(
        productId: '',
        title: 'No line items',
        imageUrls: const [],
        unitPrice: 0,
        currency: order.currency,
        quantity: 0,
      );
    }
    return order.items.first;
  }

  Future<void> _buyAgain(BuildContext context, WidgetRef ref, OrderItem line) async {
    if (line.productId.isEmpty) return;
    final qty = line.quantity < 1 ? 1 : line.quantity;
    await openBuyNowCheckout(
      context,
      ref,
      productId: line.productId,
      quantity: qty,
    );
  }
}
