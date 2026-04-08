import 'package:ecommerce_app/features/articles/pages/article_detail_page.dart';
import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArticlesPage extends ConsumerWidget {
  const ArticlesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publishedArticlesProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= 900;
    final double horizontalPadding = isWide ? 20 : 12;
    final double topBottomPadding = isWide ? 16 : 12;
    final double maxContentWidth = isWide ? 920 : double.infinity;
    return Scaffold(
      appBar: AppBar(title: const Text('Articles')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(exploreArticlesPreviewProvider);
          ref.invalidate(publishedArticlesProvider);
          ref.invalidate(articlesRevisionProvider);
          await ref.read(publishedArticlesProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            physics: AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 220),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 180),
              Center(child: Text('Could not load articles: $e')),
            ],
          ),
          data: (articles) {
            if (articles.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Text(
                      'No published articles yet.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topBottomPadding,
                    horizontalPadding,
                    topBottomPadding,
                  ),
                  children: [
                    _ArticleGroup(title: 'Articles', items: articles),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArticleGroup extends StatelessWidget {
  const _ArticleGroup({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= 900;
    final double imageSize = isWide ? 64 : 56;
    final double titleSize = isWide ? 16 : 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text('No items in this section.', style: theme.textTheme.bodyMedium)
        else
          ...items.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minVerticalPadding: 6,
                tileColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                leading: a.coverImageUrl == null || a.coverImageUrl!.isEmpty
                    ? CircleAvatar(
                        radius: imageSize / 2,
                        child: const Icon(Icons.description_outlined),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          a.coverImageUrl!,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: titleSize,
                  ),
                ),
                subtitle: Text(
                  'By ${a.authorName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Text(
                    'READ',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ArticleDetailPage(articleId: a.id),
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }
}
