import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/features/reviews/state/reviews_providers.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WriteReviewPage extends ConsumerStatefulWidget {
  const WriteReviewPage({
    super.key,
    required this.productId,
    this.productTitle,
  });

  final String productId;
  final String? productTitle;

  @override
  ConsumerState<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends ConsumerState<WriteReviewPage> {
  bool _loading = true;
  bool _submitting = false;
  int _rating = 5;
  late final TextEditingController _controller;
  String? _error;
  bool _eligible = false;
  bool _hasReview = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final svc = ref.read(reviewsServiceProvider);
    try {
      final eligibility = await svc.getMyReviewEligibility(widget.productId);
      if (!eligibility.signedIn || !eligibility.eligible) {
        if (!mounted) return;
        setState(() {
          _eligible = false;
          _hasReview = eligibility.hasReview;
          _loading = false;
        });
        return;
      }

      final draft =
          eligibility.hasReview ? await svc.getMyReviewDraft(widget.productId) : null;
      if (!mounted) return;
      setState(() {
        _eligible = true;
        _hasReview = eligibility.hasReview;
        _rating = (draft?.rating ?? 5).clamp(1, 5);
        _controller.text = draft?.text ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_eligible) return;
    setState(() => _submitting = true);
    final svc = ref.read(reviewsServiceProvider);
    final text = _controller.text.trim();
    try {
      await svc.submitProductReview(
        productId: widget.productId,
        rating: _rating,
        reviewText: text.isEmpty ? null : text,
      );
      if (!mounted) return;
      ref.invalidate(reviewEligibilityProvider(widget.productId));
      ref.invalidate(ratingDistributionProvider(widget.productId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasReview ? 'Review updated.' : 'Review submitted.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _submitting = false);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasReview ? 'Edit Review' : 'Write Review'),
      ),
      body: _loading
          ? const PageLoading(message: 'Preparing review...')
          : _error != null
              ? PageRefreshableBody(
                  onRefresh: _bootstrap,
                  child: PageErrorState(
                    title: 'Could not open review',
                    message: _error!,
                    onRetry: _bootstrap,
                  ),
                )
              : !_eligible
                  ? const PageEmptyState(
                      icon: Icons.rate_review_outlined,
                      title: 'Review not available',
                      subtitle:
                          'Only verified buyers can review after delivery for this product.',
                    )
                  : SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        children: [
                          if ((widget.productTitle ?? '').trim().isNotEmpty) ...[
                            Text(
                              widget.productTitle!.trim(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'Your rating',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final v = i + 1;
                              return IconButton(
                                onPressed: _submitting ? null : () => setState(() => _rating = v),
                                icon: Icon(
                                  v <= _rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
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
                            maxLines: 7,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Review (optional)',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(_hasReview ? 'Update review' : 'Submit review'),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
