import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/admin_product_review_row.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/product_review.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/review_eligibility.dart';
import 'package:ecommerce_app/features/reviews/domain/review_sort.dart';
import 'package:postgrest/postgrest.dart';

class SupabaseReviewsService extends SupabaseServiceBase {
  SupabaseReviewsService(super.client);

  static const int pageSize = 20;

  Future<ReviewEligibility> getMyReviewEligibility(String productId) async {
    final raw = await guard(
      () => client.rpc(
        'get_my_review_eligibility',
        params: <String, dynamic>{'p_product_id': productId},
      ),
    );
    final map = Map<String, dynamic>.from(raw as Map);
    return ReviewEligibility.fromJson(map);
  }

  /// Counts per star (1–5). Missing stars are omitted in RPC; caller may normalize.
  Future<Map<int, int>> getProductRatingDistribution(String productId) async {
    final raw = await guard(
      () => client.rpc(
        'get_product_rating_distribution',
        params: <String, dynamic>{'p_product_id': productId},
      ),
    );
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    final out = <int, int>{};
    for (var s = 1; s <= 5; s++) {
      final v = map[s.toString()];
      if (v is int) {
        out[s] = v;
      } else if (v is num) {
        out[s] = v.round();
      } else {
        out[s] = 0;
      }
    }
    return out;
  }

  Future<List<ProductReview>> listProductReviews({
    required String productId,
    required ReviewSort sort,
    required int limit,
    required int offset,
  }) async {
    final raw = await guard(
      () => client.rpc(
        'list_product_reviews',
        params: <String, dynamic>{
          'p_product_id': productId,
          'p_sort': sort.apiValue,
          'p_limit': limit,
          'p_offset': offset,
        },
      ),
    );
    final list = (raw as List)
        .map((e) => ProductReview.fromRpcRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  /// Current user’s row (including hidden), for edit prefill. Null if signed out or no row.
  Future<({int rating, String? text})?> getMyReviewDraft(String productId) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await guard(
      () => client
          .from('reviews')
          .select('rating, review_text')
          .eq('product_id', productId)
          .eq('user_id', uid)
          .maybeSingle(),
    );
    if (row == null) return null;
    final r = (row['rating'] as num?)?.round() ?? 3;
    final t = row['review_text'] as String?;
    return (rating: r.clamp(1, 5), text: t);
  }

  Future<void> submitProductReview({
    required String productId,
    required int rating,
    String? reviewText,
  }) async {
    try {
      await client.rpc(
        'submit_product_review',
        params: <String, dynamic>{
          'p_product_id': productId,
          'p_rating': rating,
          'p_review_text': reviewText,
        },
      );
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not_authenticated')) {
        throw const AuthException('Sign in to submit a review.');
      }
      if (m.contains('not_eligible')) {
        throw const ValidationException(
          'You can only review after you have a delivered order that includes this product.',
        );
      }
      if (m.contains('invalid_rating')) {
        throw const ValidationException('Please choose a rating from 1 to 5 stars.');
      }
      if (m.contains('review_text_too_long')) {
        throw const ValidationException('Review text must be at most 1,000 characters.');
      }
      if (m.contains('product_not_found')) {
        throw const ValidationException('This product is not available.');
      }
      throw RepositoryException(e.message);
    }
  }

  Future<({List<AdminProductReviewRow> items, bool hasMore})> fetchAdminProductReviewsPage({
    required int offset,
    int limit = pageSize,
  }) async {
    final take = limit.clamp(1, 50) + 1;
    final end = offset + take - 1;
    final rows = await guard(
      () => client
          .from('reviews')
          .select(
            'id, product_id, user_id, rating, review_text, is_verified_purchase, '
            'is_visible, admin_reply_text, admin_reply_updated_at, created_at, updated_at',
          )
          .order('created_at', ascending: false)
          .range(offset, end),
    ) as List<dynamic>;

    final cast = rows.cast<Map<String, dynamic>>();
    final hasMore = cast.length > limit;
    final slice = hasMore ? cast.sublist(0, limit) : cast;

    DateTime parseTs(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (v is DateTime) return v.toUtc();
      return DateTime.tryParse(v.toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    DateTime? parseTsNullable(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toUtc();
      return DateTime.tryParse(v.toString())?.toUtc();
    }

    final productIds = <String>{};
    final userIds = <String>{};
    for (final row in slice) {
      final pid = row['product_id']?.toString().trim();
      if (pid != null && pid.isNotEmpty) productIds.add(pid);
      final uid = row['user_id']?.toString().trim();
      if (uid != null && uid.isNotEmpty) userIds.add(uid);
    }

    final productTitleById = <String, String>{};
    if (productIds.isNotEmpty) {
      final productRows = await guard(
        () => client.from('products').select('id,title').inFilter('id', productIds.toList()),
      ) as List<dynamic>;
      for (final raw in productRows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id']?.toString();
        final title = m['title']?.toString().trim();
        if (id != null && id.isNotEmpty && title != null && title.isNotEmpty) {
          productTitleById[id] = title;
        }
      }
    }

    final reviewerNameById = <String, String>{};
    if (userIds.isNotEmpty) {
      final profileRows = await guard(
        () => client.from('profiles').select('id,full_name').inFilter('id', userIds.toList()),
      ) as List<dynamic>;
      for (final raw in profileRows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id']?.toString();
        final fullName = m['full_name']?.toString().trim();
        if (id != null && id.isNotEmpty && fullName != null && fullName.isNotEmpty) {
          reviewerNameById[id] = fullName;
        }
      }
    }

    final items = slice.map((row) {
      final text = row['review_text']?.toString();
      final pid = row['product_id']?.toString() ?? '';
      final uid = row['user_id']?.toString() ?? '';
      return AdminProductReviewRow(
        id: row['id'].toString(),
        productId: pid,
        productTitle: productTitleById[pid] ?? 'Product',
        userId: uid,
        reviewerName: reviewerNameById[uid] ?? 'Customer',
        rating: ((row['rating'] as num?)?.round() ?? 0).clamp(1, 5),
        reviewText: text == null || text.trim().isEmpty ? null : text.trim(),
        isVerifiedPurchase: row['is_verified_purchase'] == true,
        isVisible: row['is_visible'] == true,
        adminReplyText: (row['admin_reply_text'] as String?)?.trim().isNotEmpty == true
            ? (row['admin_reply_text'] as String).trim()
            : null,
        adminReplyUpdatedAt: parseTsNullable(row['admin_reply_updated_at']),
        createdAt: parseTs(row['created_at']),
        updatedAt: parseTs(row['updated_at']),
      );
    }).toList();

    return (items: items, hasMore: hasMore);
  }

  Future<void> setReviewVisible({
    required String reviewId,
    required bool visible,
  }) async {
    final id = reviewId.trim();
    if (id.isEmpty) {
      throw const ValidationException('Review id is required.');
    }
    try {
      await client.from('reviews').update({'is_visible': visible}).eq('id', id);
    } on PostgrestException catch (e) {
      final code = e.code;
      final msg = e.message.toLowerCase();
      if (code == '42501' || msg.contains('permission') || msg.contains('policy')) {
        throw const AuthException('You do not have permission for this action.');
      }
      throw RepositoryException(
        e.message.isNotEmpty ? e.message : 'Could not update review visibility.',
      );
    }
  }

  Future<void> setReviewAdminReply({
    required String reviewId,
    String? replyText,
  }) async {
    final id = reviewId.trim();
    if (id.isEmpty) {
      throw const ValidationException('Review id is required.');
    }
    final cleaned = replyText?.trim();
    if (cleaned != null && cleaned.length > 1000) {
      throw const ValidationException('Reply must be at most 1,000 characters.');
    }
    try {
      await client
          .from('reviews')
          .update({
            'admin_reply_text': (cleaned == null || cleaned.isEmpty) ? null : cleaned,
            'admin_reply_updated_at':
                (cleaned == null || cleaned.isEmpty) ? null : DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } on PostgrestException catch (e) {
      final code = e.code;
      final msg = e.message.toLowerCase();
      if (code == '42501' || msg.contains('permission') || msg.contains('policy')) {
        throw const AuthException('You do not have permission for this action.');
      }
      throw RepositoryException(
        e.message.isNotEmpty ? e.message : 'Could not save review reply.',
      );
    }
  }
}
