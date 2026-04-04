import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/features/product_questions/models/admin_product_question_row.dart';
import 'package:ecommerce_app/features/product_questions/models/product_answer.dart';
import 'package:ecommerce_app/features/product_questions/providers/product_questions_providers.dart';
import 'package:ecommerce_app/features/product_questions/services/supabase_product_questions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin → Product Questions: moderate questions, answer as seller, edit/delete answers.
class AdminProductQaPage extends ConsumerStatefulWidget {
  const AdminProductQaPage({super.key});

  @override
  ConsumerState<AdminProductQaPage> createState() => _AdminProductQaPageState();
}

class _AdminProductQaPageState extends ConsumerState<AdminProductQaPage> {
  final List<AdminProductQuestionRow> _items = [];
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
    });
    final svc = ref.read(productQuestionsServiceProvider);
    try {
      final page = await svc.fetchAdminProductQuestionsPage(
        offset: 0,
        limit: SupabaseProductQuestionsService.pageSize,
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
    final svc = ref.read(productQuestionsServiceProvider);
    try {
      final page = await svc.fetchAdminProductQuestionsPage(
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
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reply(AdminProductQuestionRow row) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post seller answer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row.question, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      controller.dispose();
      return;
    }
    final svc = ref.read(productQuestionsServiceProvider);
    try {
      await svc.submitProductAnswer(
        questionId: row.id,
        answer: controller.text,
      );
      controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer posted.')));
      await _reload();
    } catch (e) {
      controller.dispose();
      if (!mounted) return;
      final msg = e is AppException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _editAnswer(ProductAnswer a) async {
    final controller = TextEditingController(text: a.answer);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit answer'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Answer',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      await ref.read(productQuestionsServiceProvider).updateProductAnswer(
            answerId: a.id,
            answer: controller.text,
          );
      controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer updated.')));
      await _reload();
    } catch (e) {
      controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteAnswer(ProductAnswer a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this answer?'),
        content: Text(
          a.answer.length > 200 ? '${a.answer.substring(0, 200)}…' : a.answer,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(productQuestionsServiceProvider).deleteProductAnswer(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer removed.')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(AdminProductQuestionRow row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text(row.question.length > 160 ? '${row.question.substring(0, 160)}…' : row.question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(productQuestionsServiceProvider).deleteProductQuestion(row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question removed.')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleApproved(AdminProductQuestionRow row) async {
    try {
      await ref.read(productQuestionsServiceProvider).setQuestionApproved(
            questionId: row.id,
            approved: !row.isApproved,
          );
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
              'Product Questions',
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
          'Answer as seller, edit or remove answers, and hide spam questions. Seller and verified buyer badges show on the storefront.',
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
                      ? const Center(child: Text('No questions yet.'))
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
                            return _AdminQuestionTile(
                              row: row,
                              onReply: () => _reply(row),
                              onDelete: () => _delete(row),
                              onToggleApproved: () => _toggleApproved(row),
                              onEditAnswer: _editAnswer,
                              onDeleteAnswer: _deleteAnswer,
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _AdminQuestionTile extends StatelessWidget {
  final AdminProductQuestionRow row;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onToggleApproved;
  final void Function(ProductAnswer) onEditAnswer;
  final void Function(ProductAnswer) onDeleteAnswer;

  const _AdminQuestionTile({
    required this.row,
    required this.onReply,
    required this.onDelete,
    required this.onToggleApproved,
    required this.onEditAnswer,
    required this.onDeleteAnswer,
  });

  String _badge(ProductAnswer a) {
    if (a.isAdmin) return 'Seller Answer';
    if (a.isVerifiedPurchase) return 'Verified Buyer';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = MaterialLocalizations.of(context).formatShortDate(row.createdAt.toLocal());
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
                    Text('Q: ${row.question}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${row.askerDisplayName} · $dateStr',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!row.isApproved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hidden',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onToggleApproved,
                    icon: Icon(row.isApproved ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    label: Text(row.isApproved ? 'Hide' : 'Approve'),
                  ),
                ],
              ),
            ],
          ),
          if (row.answers.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final a in row.answers)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A: ',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.answer, style: Theme.of(context).textTheme.bodySmall),
                              if (_badge(a).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _badge(a),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                ),
                              Text(
                                a.authorDisplayName,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => onEditAnswer(a),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: () => onDeleteAnswer(a),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete answer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                onPressed: onReply,
                icon: const Icon(Icons.reply_outlined, size: 18),
                label: const Text('Reply'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete question'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
