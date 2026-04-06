import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/storefront_article.dart';
import '../services/articles_supabase_service.dart';

final articlesSupabaseServiceProvider = Provider<ArticlesSupabaseService>(
  (ref) => ArticlesSupabaseService(ref.watch(supabaseClientProvider)),
);

final articlesRevisionProvider = NotifierProvider<ArticlesRevisionNotifier, int>(
  ArticlesRevisionNotifier.new,
);

class ArticlesRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final exploreArticlesPreviewProvider =
    FutureProvider.autoDispose<List<StorefrontArticle>>((ref) async {
  ref.watch(articlesRevisionProvider);
  final svc = ref.watch(articlesSupabaseServiceProvider);
  final all = await svc.fetchPublishedArticles(limit: 30);
  return all.take(10).toList();
});

final publishedArticlesProvider =
    FutureProvider.autoDispose<List<StorefrontArticle>>((ref) async {
  ref.watch(articlesRevisionProvider);
  final svc = ref.watch(articlesSupabaseServiceProvider);
  return svc.fetchPublishedArticles(limit: 200);
});

final adminArticlesListProvider = FutureProvider.autoDispose<List<StorefrontArticle>>((ref) async {
  final svc = ref.watch(articlesSupabaseServiceProvider);
  return svc.fetchAdminArticles();
});

final articleByIdProvider =
    FutureProvider.autoDispose.family<StorefrontArticle?, String>((ref, id) async {
  ref.watch(articlesRevisionProvider);
  return ref.watch(articlesSupabaseServiceProvider).getArticleById(id);
});

final articlePurchasedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, articleId) async {
  final svc = ref.watch(articlesSupabaseServiceProvider);
  return svc.hasPurchasedArticle(articleId);
});

class ArticleAccessArgs {
  final String articleId;
  final String? checkoutProductId;
  const ArticleAccessArgs({required this.articleId, this.checkoutProductId});
}

final articleAccessProvider =
    FutureProvider.autoDispose.family<bool, ArticleAccessArgs>((ref, args) async {
  final svc = ref.watch(articlesSupabaseServiceProvider);
  if (await svc.hasPurchasedArticle(args.articleId)) return true;
  final checkoutId = args.checkoutProductId;
  if (checkoutId == null || checkoutId.isEmpty) return false;
  return svc.syncPurchaseFromPaidOrders(
    articleId: args.articleId,
    checkoutProductId: checkoutId,
  );
});
