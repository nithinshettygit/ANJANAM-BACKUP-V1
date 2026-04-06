import 'package:ecommerce_app/features/articles/models/storefront_article.dart';
import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminArticlesPage extends ConsumerWidget {
  const AdminArticlesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminArticlesListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Upload PDFs to private storage and publish articles.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openEditor(context, ref, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add article'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No articles yet.'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = rows[i];
                        return Card(
                          child: ListTile(
                            title: Text(a.title),
                            subtitle: Text(
                              '${a.authorName} • ${a.isPublished ? 'Published' : 'Draft'}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  onPressed: () => _openEditor(context, ref, a),
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  onPressed: () => _delete(context, ref, a.id),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete article?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(articlesSupabaseServiceProvider).deleteArticle(id);
      ref.invalidate(adminArticlesListProvider);
      ref.read(articlesRevisionProvider.notifier).bump();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    StorefrontArticle? existing,
  ) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final authorCtrl = TextEditingController(text: existing?.authorName ?? '');
    final bioCtrl = TextEditingController(text: existing?.authorBio ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    var isPublished = existing?.isPublished ?? true;
    var isFeatured = existing?.isFeatured ?? false;
    var isTrending = existing?.isTrending ?? false;
    String? coverPath = existing?.coverImageUrl;
    String? authorPath = existing?.authorPhotoUrl;
    String? pdfPath = existing?.pdfPath;

    Future<String?> pickAndUpload({
      required List<String> exts,
      required String folder,
      required String contentType,
    }) async {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: exts,
      );
      if (picked == null || picked.files.isEmpty) return null;
      final f = picked.files.first;
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      return ref.read(articlesSupabaseServiceProvider).uploadArticleAsset(
            folder: folder,
            bytes: bytes,
            fileName: f.name,
            contentType: contentType,
          );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Create article' : 'Edit article'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Author Name')),
                  const SizedBox(height: 10),
                  TextField(controller: bioCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Author Bio')),
                  const SizedBox(height: 10),
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Published'),
                    value: isPublished,
                    onChanged: (v) => setLocal(() => isPublished = v),
                  ),
                  SwitchListTile(
                    title: const Text('Featured'),
                    value: isFeatured,
                    onChanged: (v) => setLocal(() => isFeatured = v),
                  ),
                  SwitchListTile(
                    title: const Text('Trending'),
                    value: isTrending,
                    onChanged: (v) => setLocal(() => isTrending = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text(coverPath == null ? 'Cover: not selected' : 'Cover selected')),
                      OutlinedButton(
                        onPressed: () async {
                          final p = await pickAndUpload(
                            exts: const ['jpg', 'jpeg', 'png', 'webp'],
                            folder: 'covers',
                            contentType: 'image/jpeg',
                          );
                          if (p != null) setLocal(() => coverPath = p);
                        },
                        child: const Text('Upload cover'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(authorPath == null ? 'Author photo: not selected' : 'Author photo selected')),
                      OutlinedButton(
                        onPressed: () async {
                          final p = await pickAndUpload(
                            exts: const ['jpg', 'jpeg', 'png', 'webp'],
                            folder: 'authors',
                            contentType: 'image/jpeg',
                          );
                          if (p != null) setLocal(() => authorPath = p);
                        },
                        child: const Text('Upload author'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(pdfPath == null ? 'PDF: not selected' : 'PDF selected')),
                      OutlinedButton(
                        onPressed: () async {
                          final p = await pickAndUpload(
                            exts: const ['pdf'],
                            folder: 'pdfs',
                            contentType: 'application/pdf',
                          );
                          if (p != null) setLocal(() => pdfPath = p);
                        },
                        child: const Text('Upload PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    authorCtrl.text.trim().isEmpty ||
                    pdfPath == null ||
                    pdfPath!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title, author, and PDF are required.')),
                  );
                  return;
                }
                try {
                  final row = <String, dynamic>{
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'author_name': authorCtrl.text.trim(),
                    'author_bio': bioCtrl.text.trim(),
                    'author_photo_url': authorPath,
                    'cover_image_url': coverPath,
                    'pdf_url': pdfPath,
                    'category': categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                    'is_free': true,
                    'price': 0.0,
                    'is_published': isPublished,
                    'is_featured': isFeatured,
                    'is_trending': isTrending,
                  };
                  if (existing == null) {
                    await ref.read(articlesSupabaseServiceProvider).createArticle(row);
                  } else {
                    await ref.read(articlesSupabaseServiceProvider).updateArticle(existing.id, row);
                  }
                  if (context.mounted) Navigator.pop(ctx);
                  ref.invalidate(adminArticlesListProvider);
                  ref.read(articlesRevisionProvider.notifier).bump();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(userFacingErrorMessage(e))),
                  );
                }
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    descCtrl.dispose();
    authorCtrl.dispose();
    bioCtrl.dispose();
    categoryCtrl.dispose();
  }
}
