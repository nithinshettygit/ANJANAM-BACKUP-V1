import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/admin_product_review_row.dart';
import 'package:ecommerce_app/features/reviews/state/reviews_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminProductReviewsPage extends ConsumerStatefulWidget {
  const AdminProductReviewsPage({super.key});

  @override
  ConsumerState<AdminProductReviewsPage> createState() => _AdminProductReviewsPageState();
}

class _AdminProductReviewsPageState extends ConsumerState<AdminProductReviewsPage> {
  final List<AdminProductReviewRow> _items = [];
  final Set<String> _pendingReviewIds = <String>{};
  int _offset = 0;
  bool _initialLoading = true;
  bool _loadingMore = false;
  String? _error;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _offset = 0;
      _items.clear();
      _hasMore = true;
      _pendingReviewIds.clear();
    });
    final svc = ref.read(reviewsServiceProvider);
    try {
      final page = await svc.fetchAdminProductReviewsPage(
        offset: 0,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _offset = page.items.length;
        _hasMore = page.hasMore;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    final svc = ref.read(reviewsServiceProvider);
    try {
      final page = await svc.fetchAdminProductReviewsPage(
        offset: _offset,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _offset += page.items.length;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleVisibility(AdminProductReviewRow row) async {
    if (_pendingReviewIds.contains(row.id)) return;
    setState(() => _pendingReviewIds.add(row.id));
    final svc = ref.read(reviewsServiceProvider);
    final nextVisible = !row.isVisible;
    try {
      await svc.setReviewVisible(reviewId: row.id, visible: nextVisible);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((e) => e.id == row.id);
        if (i >= 0) {
          _items[i] = AdminProductReviewRow(
            id: row.id,
            productId: row.productId,
            productTitle: row.productTitle,
            userId: row.userId,
            reviewerName: row.reviewerName,
            rating: row.rating,
            reviewText: row.reviewText,
            isVerifiedPurchase: row.isVerifiedPurchase,
            isVisible: nextVisible,
            createdAt: row.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextVisible ? 'Review is now visible.' : 'Review hidden from storefront.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() => _pendingReviewIds.remove(row.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Product Reviews',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _initialLoading ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Moderate customer reviews. Hide misleading content from storefront and show it back when resolved.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _initialLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : _items.isEmpty
                      ? const Center(child: Text('No reviews yet.'))
                      : ListView.separated(
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return TextButton(
                                onPressed: _loadingMore ? null : _loadMore,
                                child: _loadingMore
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Load more'),
                              );
                            }
                            final row = _items[i];
                            return _AdminReviewTile(
                              row: row,
                              isPending: _pendingReviewIds.contains(row.id),
                              onToggleVisibility: () => _toggleVisibility(row),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _AdminReviewTile extends StatelessWidget {
  final AdminProductReviewRow row;
  final bool isPending;
  final VoidCallback onToggleVisibility;

  const _AdminReviewTile({
    required this.row,
    required this.isPending,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = MaterialLocalizations.of(context).formatShortDate(row.createdAt.toLocal());
    final reviewText = row.reviewText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.productTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(row.reviewerName),
                        Text('•'),
                        _RatingStars(rating: row.rating),
                        Text('•'),
                        Text(dateStr),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: row.isVisible
                      ? Colors.green.withOpacity(0.14)
                      : Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  row.isVisible ? 'Visible' : 'Hidden',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reviewText == null || reviewText.isEmpty ? 'Rating only (no written review).' : reviewText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (row.isVerifiedPurchase) ...[
            const SizedBox(height: 6),
            Text(
              'Verified Purchase',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: isPending ? null : onToggleVisibility,
            icon: Icon(
              row.isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
            ),
            label: Text(
              isPending ? 'Please wait...' : (row.isVisible ? 'Hide review' : 'Show review'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: Colors.amber.shade700,
        );
      }),
    );
  }
}
