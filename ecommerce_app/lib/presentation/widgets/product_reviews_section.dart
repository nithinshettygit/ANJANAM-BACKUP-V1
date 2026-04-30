import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/product_review.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/review_eligibility.dart';
import 'package:ecommerce_app/features/reviews/domain/review_sort.dart';
import 'package:ecommerce_app/features/reviews/data/services/supabase_reviews_service.dart';
import 'package:ecommerce_app/features/reviews/state/reviews_providers.dart';
import 'package:ecommerce_app/presentation/widgets/star_rating_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [embeddedPreview]: short teaser on product detail (Flipkart-style) with **View all**.
/// [fullScreen]: full list with sort and load more (opened from **View all**).
enum ProductReviewsListMode { embeddedPreview, fullScreen }

String _formatWithCommas(int n) {
  final digits = n.toString();
  if (digits.length <= 3) return digits;
  final buf = StringBuffer();
  var start = digits.length % 3;
  if (start == 0) start = 3;
  buf.write(digits.substring(0, start));
  for (var i = start; i < digits.length; i += 3) {
    buf.write(',');
    buf.write(digits.substring(i, i + 3 > digits.length ? digits.length : i + 3));
  }
  return buf.toString();
}

class ProductReviewsSection extends ConsumerStatefulWidget {
  final Product product;
  final ProductReviewsListMode listMode;

  const ProductReviewsSection({
    super.key,
    required this.product,
    this.listMode = ProductReviewsListMode.fullScreen,
  });

  /// Teaser count on the product detail page.
  static const int kPreviewVisibleReviews = 3;

  /// Fetch a few extra to detect “more” without another round-trip.
  static const int kPreviewFetchLimit = 8;

  @override
  ConsumerState<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends ConsumerState<ProductReviewsSection> {
  ReviewSort _sort = ReviewSort.recent;
  final List<ProductReview> _items = [];
  int _offset = 0;
  bool _initialLoading = true;
  bool _loadingMore = false;
  String? _listError;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _reloadList();
  }

  void _onCatalogRevisionBumped(int? previous, int next) {
    if (previous == null || previous == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ignore: discarded_futures
        _reloadList();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id || oldWidget.listMode != widget.listMode) {
      // ignore: discarded_futures
      _reloadList();
    }
  }

  int get _initialFetchLimit => widget.listMode == ProductReviewsListMode.embeddedPreview
      ? ProductReviewsSection.kPreviewFetchLimit
      : SupabaseReviewsService.pageSize;

  Future<void> _reloadList() async {
    setState(() {
      _initialLoading = true;
      _listError = null;
      _offset = 0;
      _items.clear();
      _hasMore = true;
    });
    final svc = ref.read(reviewsServiceProvider);
    try {
      final page = await svc.listProductReviews(
        productId: widget.product.id,
        sort: _sort,
        limit: _initialFetchLimit,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _offset = page.length;
        _hasMore = page.length >= _initialFetchLimit;
        _initialLoading = false;
      });
    } catch (e) {
      // Keep backend details out of the storefront UI.
      debugPrint('Product reviews fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _listError = 'Unable to load reviews right now.';
        _initialLoading = false;
      });
    }
  }

  Future<void> _setSort(ReviewSort s) async {
    if (s == _sort && _items.isNotEmpty) return;
    setState(() => _sort = s);
    await _reloadList();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    final svc = ref.read(reviewsServiceProvider);
    try {
      final page = await svc.listProductReviews(
        productId: widget.product.id,
        sort: _sort,
        limit: SupabaseReviewsService.pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _offset += page.length;
        _hasMore = page.length >= SupabaseReviewsService.pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Product reviews load-more failed: $e');
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load more reviews right now.')),
        );
      });
    }
  }

  void _openAllReviews(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => ProductReviewsAllPage(product: widget.product),
      ),
    );
  }

  Future<void> _openReviewSheet(ReviewEligibility eligibility) async {
    if (!eligibility.signedIn || !eligibility.eligible) return;
    final svc = ref.read(reviewsServiceProvider);
    final draft = eligibility.hasReview ? await svc.getMyReviewDraft(widget.product.id) : null;
    if (!mounted) return;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ReviewEditorSheet(
        productId: widget.product.id,
        productTitle: widget.product.title,
        initialRating: draft?.rating ?? 5,
        initialText: draft?.text,
        isEdit: eligibility.hasReview,
      ),
    );
    if (submitted == true && mounted) {
      ref.read(storefrontCatalogRevisionProvider.notifier).bump();
      ref.invalidate(reviewEligibilityProvider(widget.product.id));
      ref.invalidate(ratingDistributionProvider(widget.product.id));
      await _reloadList();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(storefrontCatalogRevisionProvider, _onCatalogRevisionBumped);
    final product = widget.product;
    final distAsync = ref.watch(ratingDistributionProvider(product.id));
    final eligAsync = ref.watch(reviewEligibilityProvider(product.id));
    final isPreview = widget.listMode == ProductReviewsListMode.embeddedPreview;
    final visibleReviews = isPreview
        ? ProductReviewsSection.kPreviewVisibleReviews.clamp(0, _items.length)
        : _items.length;
    final showViewAllReviews = isPreview &&
        !_initialLoading &&
        _listError == null &&
        product.totalReviews > 0 &&
        (product.totalReviews > ProductReviewsSection.kPreviewVisibleReviews ||
            _items.length > ProductReviewsSection.kPreviewVisibleReviews ||
            _hasMore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPreview) ...[
          Text(
            'Ratings & reviews',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (product.totalReviews > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Showing a few top reviews — tap below to read them all.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 4),
        _SummaryRow(product: product),
        const SizedBox(height: 16),
        distAsync.when(
          data: (dist) => _DistributionBars(
            distribution: dist,
            totalRatings: product.totalReviews,
          ),
          loading: () => const LinearProgressIndicator(minHeight: 3),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        eligAsync.when(
          data: (e) => _ReviewActionRow(
            eligibility: e,
            onPressed: () => _openReviewSheet(e),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        if (!isPreview) ...[
          const SizedBox(height: 16),
          Text(
            'Sort by',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReviewSort.values.map((s) {
              final selected = s == _sort;
              return ChoiceChip(
                label: Text(s.label),
                selected: selected,
                onSelected: (_) {
                  // ignore: discarded_futures
                  _setSort(s);
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 16),
        if (_initialLoading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_listError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _listError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _reloadList,
                child: const Text('Retry'),
              ),
            ],
          )
        else if (_items.isEmpty && product.totalReviews > 0)
          Text(
            'No reviews yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleReviews + (isPreview ? 0 : (_hasMore ? 1 : 0)),
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, i) {
              if (!isPreview && i >= _items.length) {
                return Center(
                  child: TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                );
              }
              return _ReviewTile(review: _items[i]);
            },
          ),
        if (showViewAllReviews) ...[
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openAllReviews(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'View all ${_formatWithCommas(product.totalReviews)} ratings & reviews',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.deepGold,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.deepGold),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Full-screen reviews (opened from product detail **View all**).
class ProductReviewsAllPage extends StatelessWidget {
  final Product product;

  const ProductReviewsAllPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratings & reviews'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ProductReviewsSection(
            product: product,
            listMode: ProductReviewsListMode.fullScreen,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final Product product;

  const _SummaryRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final avg = product.averageRating;
    final tr = product.totalReviews;
    final tw = product.totalWrittenReviews;
    if (avg == null || tr <= 0) {
      return Text(
        'No reviews yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⭐ ',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${avg.toStringAsFixed(1)} / 5',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatWithCommas(tr)} Ratings & ${_formatWithCommas(tw)} Reviews',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistributionBars extends StatelessWidget {
  final Map<int, int> distribution;
  final int totalRatings;

  const _DistributionBars({
    required this.distribution,
    required this.totalRatings,
  });

  @override
  Widget build(BuildContext context) {
    if (totalRatings <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating breakdown',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (var star = 5; star >= 1; star--)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '$star★',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalRatings > 0
                          ? (distribution[star] ?? 0) / totalRatings
                          : 0,
                      minHeight: 8,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    totalRatings > 0
                        ? '${(((distribution[star] ?? 0) / totalRatings) * 100).round()}%'
                        : '0%',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewActionRow extends StatelessWidget {
  final ReviewEligibility eligibility;
  final VoidCallback onPressed;

  const _ReviewActionRow({
    required this.eligibility,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!eligibility.signedIn) {
      return Text(
        'Sign in to write a review.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    if (!eligibility.eligible) {
      return Text(
        'You can review after this product is delivered.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(eligibility.hasReview ? Icons.edit : Icons.rate_review_outlined),
        label: Text(eligibility.hasReview ? 'Edit your review' : 'Write a review'),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ProductReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final dateStr = MaterialLocalizations.of(context).formatShortDate(
      review.createdAt.toLocal(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.authorDisplayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            StarRatingDisplay(rating: review.rating, size: 16),
          ],
        ),
        if (review.isVerifiedPurchase) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Verified Purchase',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        if (review.reviewText != null && review.reviewText!.trim().isNotEmpty)
          Text(review.reviewText!, style: Theme.of(context).textTheme.bodyMedium)
        else
          Text(
            'Rating only',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        if (review.adminReplyText != null && review.adminReplyText!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller reply',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  review.adminReplyText!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ReviewEditorSheet extends ConsumerStatefulWidget {
  final String productId;
  final String productTitle;
  final int initialRating;
  final String? initialText;
  final bool isEdit;

  const _ReviewEditorSheet({
    required this.productId,
    required this.productTitle,
    required this.initialRating,
    required this.initialText,
    required this.isEdit,
  });

  @override
  ConsumerState<_ReviewEditorSheet> createState() => _ReviewEditorSheetState();
}

class _ReviewEditorSheetState extends ConsumerState<_ReviewEditorSheet> {
  late int _rating;
  late TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(1, 5);
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final svc = ref.read(reviewsServiceProvider);
    setState(() => _submitting = true);
    try {
      await svc.submitProductReview(
        productId: widget.productId,
        rating: _rating,
        reviewText: text.isEmpty ? null : text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e is AppException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isEdit ? 'Edit review' : 'Write a review',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.productTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Text('Your rating', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final v = i + 1;
              return IconButton(
                onPressed: _submitting ? null : () => setState(() => _rating = v),
                icon: Icon(
                  v <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 40,
                  color: AppColors.marigoldOrange,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: !_submitting,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Review (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting
                ? null
                : () {
                    // ignore: discarded_futures
                    _submit();
                  },
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEdit ? 'Update review' : 'Submit review'),
          ),
        ],
      ),
    );
  }
}
