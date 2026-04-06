import 'dart:typed_data';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../models/storefront_article.dart';

class ArticlesSupabaseService extends SupabaseServiceBase {
  ArticlesSupabaseService(super.client);

  static const _columns = '''
id, title, description, author_name, author_bio, author_photo_url, cover_image_url,
pdf_url, category, is_free, price, is_published, is_featured, is_trending, checkout_product_id, created_at
''';

  bool _isHttpUrl(String? value) {
    final v = value?.trim() ?? '';
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<Map<String, dynamic>> _resolveStorefrontMedia(Map<String, dynamic> row) async {
    final resolved = Map<String, dynamic>.from(row);
    final cover = resolved['cover_image_url']?.toString();
    final author = resolved['author_photo_url']?.toString();
    if (cover != null && cover.isNotEmpty && !_isHttpUrl(cover)) {
      resolved['cover_image_url'] =
          await client.storage.from('articles').createSignedUrl(cover, 60 * 60);
    }
    if (author != null && author.isNotEmpty && !_isHttpUrl(author)) {
      resolved['author_photo_url'] =
          await client.storage.from('articles').createSignedUrl(author, 60 * 60);
    }
    return resolved;
  }

  Future<List<StorefrontArticle>> fetchPublishedArticles({int limit = 60}) async {
    final data = await guard(
      () => client
          .from('articles')
          .select(_columns)
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .range(0, limit - 1),
    );
    final rows = (data as List).cast<Map<String, dynamic>>();
    final resolved = <StorefrontArticle>[];
    for (final row in rows) {
      final mapped = await _resolveStorefrontMedia(row);
      resolved.add(StorefrontArticle.fromRow(mapped));
    }
    return resolved;
  }

  Future<List<StorefrontArticle>> fetchAdminArticles({int limit = 500}) async {
    final data = await guard(
      () => client
          .from('articles')
          .select(_columns)
          .order('created_at', ascending: false)
          .range(0, limit - 1),
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(StorefrontArticle.fromRow)
        .toList();
  }

  Future<StorefrontArticle?> getArticleById(String articleId) async {
    final row = await guard(
      () => client.from('articles').select(_columns).eq('id', articleId).maybeSingle(),
    );
    if (row == null) return null;
    final mapped = await _resolveStorefrontMedia(Map<String, dynamic>.from(row));
    return StorefrontArticle.fromRow(mapped);
  }

  Future<String?> findArticleIdByCheckoutProductId(String productId) async {
    if (productId.trim().isEmpty) return null;
    final row = await guard(
      () => client
          .from('articles')
          .select('id')
          .eq('checkout_product_id', productId.trim())
          .maybeSingle(),
    );
    return row?['id']?.toString();
  }

  Future<int?> fetchCheckoutProductStock(String productId) async {
    if (productId.trim().isEmpty) return null;
    final row = await guard(
      () => client
          .from('products')
          .select('inventory_count')
          .eq('id', productId.trim())
          .maybeSingle(),
    );
    return (row?['inventory_count'] as num?)?.toInt();
  }

  Future<void> updateCheckoutProductStock({
    required String productId,
    required int stockCount,
  }) async {
    await guard(
      () => client
          .from('products')
          .update({'inventory_count': stockCount < 0 ? 0 : stockCount})
          .eq('id', productId.trim()),
    );
  }

  Future<bool> hasPurchasedArticle(String articleId) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final row = await guard(
      () => client
          .from('article_purchases')
          .select('id')
          .eq('user_id', user.id)
          .eq('article_id', articleId)
          .limit(1),
    );
    return (row as List).isNotEmpty;
  }

  Future<bool> syncPurchaseFromPaidOrders({
    required String articleId,
    required String checkoutProductId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final already = await hasPurchasedArticle(articleId);
    if (already) return true;
    final rows = await guard(
      () => client
          .from('orders')
          .select('id, payment_status, order_items!inner(product_id)')
          .eq('user_id', user.id)
          .eq('payment_status', 'paid')
          .eq('order_items.product_id', checkoutProductId)
          .limit(1),
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return false;
    final orderId = list.first['id']?.toString();
    await createPurchaseRecord(articleId: articleId, orderId: orderId);
    return true;
  }

  Future<void> createPurchaseRecord({
    required String articleId,
    String? orderId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    await guard(
      () => client.from('article_purchases').upsert({
        'user_id': user.id,
        'article_id': articleId,
        'order_id': orderId,
      }, onConflict: 'user_id,article_id'),
    );
  }

  Future<String> createSignedPdfUrl({
    required String pdfPath,
    int expiresInSeconds = 90,
  }) async {
    return client.storage.from('articles').createSignedUrl(
          pdfPath,
          expiresInSeconds,
        );
  }

  Future<String> uploadArticleAsset({
    required String folder,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final objectPath = '$folder/${stamp}_$sanitized';
    await guard(
      () => client.storage.from('articles').uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          ),
    );
    return objectPath;
  }

  Future<String> createArticle(Map<String, dynamic> row) async {
    final created = await guard(
      () => client.from('articles').insert(row).select('id').single(),
    );
    return (created['id'] ?? '').toString();
  }

  Future<void> updateArticle(String id, Map<String, dynamic> row) async {
    await guard(() => client.from('articles').update(row).eq('id', id));
  }

  Future<void> deleteArticle(String id) async {
    await guard(() => client.from('articles').delete().eq('id', id));
  }

  Future<void> ensureCheckoutProduct(String articleId) async {
    await guard(
      () => client.rpc(
        'ensure_article_checkout_product',
        params: {'p_article_id': articleId},
      ),
    );
  }
}
