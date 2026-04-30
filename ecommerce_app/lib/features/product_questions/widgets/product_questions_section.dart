import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/features/product_questions/models/product_answer.dart';
import 'package:ecommerce_app/features/product_questions/models/product_qna_answer_eligibility.dart';
import 'package:ecommerce_app/features/product_questions/models/product_question.dart';
import 'package:ecommerce_app/features/product_questions/providers/product_questions_providers.dart';
import 'dart:math' as math;

import 'package:ecommerce_app/features/product_questions/services/supabase_product_questions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [embeddedPreview]: short teaser on product detail with **View all Q&A**.
/// [fullScreen]: full list with load more (opened from **View all**).
enum ProductQuestionsListMode { embeddedPreview, fullScreen }

/// Product detail Q&A block (below ratings & reviews).
class ProductQuestionsSection extends ConsumerStatefulWidget {
  final Product product;
  final ProductQuestionsListMode listMode;

  const ProductQuestionsSection({
    super.key,
    required this.product,
    this.listMode = ProductQuestionsListMode.fullScreen,
  });

  static const int kPreviewVisibleQuestions = 2;
  static const int kPreviewFetchLimit = 6;
  static const int kPreviewMaxAnswersPerQuestion = 2;

  @override
  ConsumerState<ProductQuestionsSection> createState() => _ProductQuestionsSectionState();
}

class _ProductQuestionsSectionState extends ConsumerState<ProductQuestionsSection> {
  final List<ProductQuestion> _items = [];
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
        ref.invalidate(productQnaAnswerEligibilityProvider(widget.product.id));
        // ignore: discarded_futures
        _reloadList();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductQuestionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id || oldWidget.listMode != widget.listMode) {
      // ignore: discarded_futures
      _reloadList();
    }
  }

  int get _initialFetchLimit => widget.listMode == ProductQuestionsListMode.embeddedPreview
      ? ProductQuestionsSection.kPreviewFetchLimit
      : SupabaseProductQuestionsService.pageSize;

  Future<void> _reloadList() async {
    setState(() {
      _initialLoading = true;
      _listError = null;
      _offset = 0;
      _items.clear();
      _hasMore = true;
    });
    final svc = ref.read(productQuestionsServiceProvider);
    try {
      final page = await svc.fetchProductQuestions(
        productId: widget.product.id,
        offset: 0,
        limit: _initialFetchLimit,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _offset = page.items.length;
        _hasMore = page.hasMore;
        _initialLoading = false;
      });
    } catch (e) {
      // Avoid showing raw backend exceptions in the UI (permission errors, RPC hints, etc).
      // Log for debugging but keep user-facing copy clean.
      // ignore: avoid_print
      debugPrint('Product Q&A fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _listError = 'Unable to load questions right now.';
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    final svc = ref.read(productQuestionsServiceProvider);
    try {
      final page = await svc.fetchProductQuestions(
        productId: widget.product.id,
        offset: _offset,
        limit: SupabaseProductQuestionsService.pageSize,
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
      setState(() {
        _loadingMore = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load more questions: $e')),
        );
      });
    }
  }

  Future<void> _openAskDialog() async {
    final signedIn = ref.read(supabaseClientProvider).auth.currentUser != null;
    if (!signedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to ask a question.')),
      );
      return;
    }
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AskQuestionDialog(
        productId: widget.product.id,
        productTitle: widget.product.title,
      ),
    );
    if (submitted == true && mounted) {
      ref.read(storefrontCatalogRevisionProvider.notifier).bump();
      ref.invalidate(productQnaAnswerEligibilityProvider(widget.product.id));
      await _reloadList();
    }
  }

  Future<void> _afterAnswerPosted() async {
    ref.read(storefrontCatalogRevisionProvider.notifier).bump();
    ref.invalidate(productQnaAnswerEligibilityProvider(widget.product.id));
    await _reloadList();
  }

  void _openAllQuestions(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => ProductQuestionsAllPage(product: widget.product),
      ),
    );
  }

  Widget _buildQuestionList(ProductQnaAnswerEligibility elig) {
    final isPreview = widget.listMode == ProductQuestionsListMode.embeddedPreview;
    final visibleCount = isPreview
        ? math.min(ProductQuestionsSection.kPreviewVisibleQuestions, _items.length)
        : _items.length;
    final maxAnswers = isPreview ? ProductQuestionsSection.kPreviewMaxAnswersPerQuestion : null;
    final showLoadMore = !isPreview && _hasMore;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleCount + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, i) {
        if (showLoadMore && i >= visibleCount) {
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
        return _QuestionBlock(
          product: widget.product,
          question: _items[i],
          eligibility: elig,
          onAnswerPosted: _afterAnswerPosted,
          maxAnswersToShow: maxAnswers,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(storefrontCatalogRevisionProvider, _onCatalogRevisionBumped);
    final eligAsync = ref.watch(productQnaAnswerEligibilityProvider(widget.product.id));
    final isPreview = widget.listMode == ProductQuestionsListMode.embeddedPreview;
    final showViewAll = isPreview &&
        !_initialLoading &&
        _listError == null &&
        _items.isNotEmpty &&
        (_items.length > ProductQuestionsSection.kPreviewVisibleQuestions || _hasMore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPreview) ...[
          Text(
            'Questions & answers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (!_initialLoading && _items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'A quick look — open the full Q&A for every question and answer.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _openAskDialog,
            icon: const Icon(Icons.help_outline),
            label: const Text('Ask a question'),
          ),
        ),
        const SizedBox(height: 16),
        if (_initialLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
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
        else if (_items.isEmpty)
          Text(
            'No questions yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          eligAsync.when(
            data: _buildQuestionList,
            loading: () => _buildQuestionList(
              const ProductQnaAnswerEligibility(isAdmin: false, canAnswerAsVerifiedBuyer: false),
            ),
            error: (_, __) => _buildQuestionList(
              const ProductQnaAnswerEligibility(isAdmin: false, canAnswerAsVerifiedBuyer: false),
            ),
          ),
        if (showViewAll) ...[
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openAllQuestions(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'View all questions & answers',
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

/// Full-screen Q&A (opened from product detail **View all**).
class ProductQuestionsAllPage extends StatelessWidget {
  final Product product;

  const ProductQuestionsAllPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questions & answers'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ProductQuestionsSection(
            product: product,
            listMode: ProductQuestionsListMode.fullScreen,
          ),
        ],
      ),
    );
  }
}

class _QuestionBlock extends ConsumerWidget {
  final Product product;
  final ProductQuestion question;
  final ProductQnaAnswerEligibility eligibility;
  final Future<void> Function() onAnswerPosted;
  /// When set (product detail preview), only this many answers are shown per question.
  final int? maxAnswersToShow;

  const _QuestionBlock({
    required this.product,
    required this.question,
    required this.eligibility,
    required this.onAnswerPosted,
    this.maxAnswersToShow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = MaterialLocalizations.of(context).formatShortDate(
      question.createdAt.toLocal(),
    );
    final canAnswer = eligibility.canAnswerAny;
    final answerCtaLabel = eligibility.isAdmin ? 'Answer this question' : 'Write an answer';
    final cap = maxAnswersToShow;
    final hiddenAnswerCount = cap != null && question.answers.length > cap
        ? question.answers.length - cap
        : 0;
    final answersToRender = cap != null && question.answers.length > cap
        ? question.answers.take(cap).toList(growable: false)
        : question.answers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q: ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGold,
                  ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.question,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${question.authorDisplayName} · $dateStr',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (question.answers.isEmpty)
          Text(
            canAnswer ? 'Be the first to answer' : 'No answers yet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else ...[
          ...answersToRender.map((a) => _AnswerLine(answer: a)),
          if (hiddenAnswerCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ $hiddenAnswerCount more answer${hiddenAnswerCount == 1 ? '' : 's'} in full Q&A',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
        ],
        if (canAnswer) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final signedIn = ref.read(supabaseClientProvider).auth.currentUser != null;
                if (!signedIn) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign in to post an answer.')),
                    );
                  }
                  return;
                }
                final isAdmin = eligibility.isAdmin;
                final title = isAdmin ? 'Answer this question' : 'Write an answer';
                final submitted = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => _PostAnswerDialog(
                    title: title,
                    productTitle: product.title,
                    questionPreview: question.question,
                    questionId: question.id,
                  ),
                );
                if (submitted == true && context.mounted) {
                  await onAnswerPosted();
                }
              },
              icon: const Icon(Icons.reply_outlined, size: 18),
              label: Text(answerCtaLabel),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final ProductAnswer answer;

  const _AnswerLine({required this.answer});

  @override
  Widget build(BuildContext context) {
    final dateStr = MaterialLocalizations.of(context).formatShortDate(
      answer.createdAt.toLocal(),
    );
    final badge = answer.answerBadgeLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A: ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestGreen,
                ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer.answer,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: answer.isAdmin
                          ? AppColors.marigoldOrange.withOpacity(0.2)
                          : AppColors.forestGreen.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: answer.isAdmin ? AppColors.deepGold : AppColors.forestGreen,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${answer.authorDisplayName} · $dateStr',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAnswerDialog extends ConsumerStatefulWidget {
  final String title;
  final String productTitle;
  final String questionPreview;
  final String questionId;

  const _PostAnswerDialog({
    required this.title,
    required this.productTitle,
    required this.questionPreview,
    required this.questionId,
  });

  @override
  ConsumerState<_PostAnswerDialog> createState() => _PostAnswerDialogState();
}

class _PostAnswerDialogState extends ConsumerState<_PostAnswerDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final svc = ref.read(productQuestionsServiceProvider);
    setState(() => _submitting = true);
    try {
      await svc.submitProductAnswer(questionId: widget.questionId, answer: _controller.text);
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
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.productTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Q: ${widget.questionPreview}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Your answer',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  // ignore: discarded_futures
                  _submit();
                },
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _AskQuestionDialog extends ConsumerStatefulWidget {
  final String productId;
  final String productTitle;

  const _AskQuestionDialog({
    required this.productId,
    required this.productTitle,
  });

  @override
  ConsumerState<_AskQuestionDialog> createState() => _AskQuestionDialogState();
}

class _AskQuestionDialogState extends ConsumerState<_AskQuestionDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final svc = ref.read(productQuestionsServiceProvider);
    setState(() => _submitting = true);
    try {
      await svc.askProductQuestion(productId: widget.productId, question: _controller.text);
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
    return AlertDialog(
      title: const Text('Ask a question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.productTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Your question',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  // ignore: discarded_futures
                  _submit();
                },
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
