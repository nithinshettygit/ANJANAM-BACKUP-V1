import 'package:ecommerce_app/features/articles/pages/secure_article_reader_page.dart';
import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:ecommerce_app/presentation/utils/universal_share.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArticleDetailPage extends ConsumerWidget {
  const ArticleDetailPage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleByIdProvider(articleId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        actions: [
          articleAsync.maybeWhen(
            data: (article) {
              if (article == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
                onPressed: () async {
                  await showUniversalShareSheet(
                    context,
                    payload: UniversalSharePayload(
                      contentType: ShareContentType.article,
                      idOrSlug: article.id,
                      title: article.title,
                      description: article.description,
                      imageUrl: article.coverImageUrl,
                    ),
                  );
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: articleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (article) {
          if (article == null) {
            return const Center(child: Text('Article not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(article.coverImageUrl!, height: 220, fit: BoxFit.cover),
                ),
              const SizedBox(height: 14),
              Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('By ${article.authorName}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: const Text('READ'),
                    backgroundColor: Colors.green.shade50,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: article.authorPhotoUrl != null && article.authorPhotoUrl!.isNotEmpty
                      ? NetworkImage(article.authorPhotoUrl!)
                      : null,
                  child: (article.authorPhotoUrl == null || article.authorPhotoUrl!.isEmpty)
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                title: Text(article.authorName),
                subtitle: Text(article.authorBio),
              ),
              const SizedBox(height: 10),
              Text(article.description),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openReader(context, ref, article.id, article.title, article.pdfPath),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Read Article'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openReader(
    BuildContext context,
    WidgetRef ref,
    String articleId,
    String title,
    String pdfPath,
  ) async {
    try {
      final url = await ref.read(articlesSupabaseServiceProvider).createSignedPdfUrl(pdfPath: pdfPath);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SecureArticleReaderPage(title: title, signedPdfUrl: url),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    }
  }
}
