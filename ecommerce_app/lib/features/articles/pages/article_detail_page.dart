import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/core/web/web_seo.dart';
import 'package:flutter/foundation.dart';
import 'package:ecommerce_app/features/articles/pages/secure_article_reader_page.dart';
import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:ecommerce_app/presentation/utils/universal_share.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _looksLikeAuthOrAccessError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('jwt') ||
      s.contains('not authorized') ||
      s.contains('unauthor') ||
      s.contains(' 403') ||
      s.contains('403 ') ||
      s.contains('forbidden') ||
      s.contains('row-level security') ||
      s.contains('permission denied') ||
      s.contains('invalid claim');
}

String _articleDetailLoadErrorMessage(Object e) {
  if (_looksLikeAuthOrAccessError(e)) {
    return 'Sign in to view this article. Log in or create an account, then try again.';
  }
  return userFacingErrorMessage(e);
}

class ArticleDetailPage extends ConsumerWidget {
  const ArticleDetailPage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleByIdProvider(articleId));
    final theme = Theme.of(context);
    final signedIn = ref.watch(supabaseClientProvider).auth.currentUser != null;
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 44, color: theme.colorScheme.outline),
                const SizedBox(height: 14),
                Text(
                  _articleDetailLoadErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (_looksLikeAuthOrAccessError(e)) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    child: const Text('Sign in'),
                  ),
                ],
              ],
            ),
          ),
        ),
        data: (article) {
          if (kIsWeb && article != null) {
            WebSeo.updateSharePage(
              title: '${article.title} — ANJANAM',
              description: article.description.isNotEmpty
                  ? article.description
                  : 'Read ${article.title} on ANJANAM.',
              path: '/article/${article.id}',
              imageUrl: article.coverImageUrl,
              ogType: 'article',
            );
          }
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
                onPressed: () {
                  if (!signedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in to read articles.'),
                      ),
                    );
                    Navigator.of(context).pushNamed('/login');
                    return;
                  }
                  _openReader(context, ref, article.id, article.title, article.pdfPath);
                },
                icon: Icon(signedIn ? Icons.menu_book_outlined : Icons.login_rounded),
                label: Text(signedIn ? 'Read Article' : 'Sign in to read'),
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
    if (ref.read(supabaseClientProvider).auth.currentUser == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to read articles.')),
      );
      await Navigator.of(context).pushNamed('/login');
      return;
    }
    try {
      final url = await ref.read(articlesSupabaseServiceProvider).createSignedPdfUrl(pdfPath: pdfPath);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SecureArticleReaderPage(title: title, signedPdfUrl: url),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = _looksLikeAuthOrAccessError(e)
          ? 'Sign in to read this article, or check that you are still logged in.'
          : userFacingErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
}
