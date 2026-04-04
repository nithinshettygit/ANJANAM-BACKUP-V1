import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
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
}
