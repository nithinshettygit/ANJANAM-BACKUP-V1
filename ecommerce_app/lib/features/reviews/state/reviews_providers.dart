import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/reviews/data/services/supabase_reviews_service.dart';
import 'package:ecommerce_app/features/reviews/domain/entities/review_eligibility.dart';

final reviewsServiceProvider = Provider<SupabaseReviewsService>(
  (ref) => SupabaseReviewsService(ref.watch(supabaseClientProvider)),
);

final reviewEligibilityProvider =
    FutureProvider.autoDispose.family<ReviewEligibility, String>(
  (ref, productId) async {
    ref.watch(authSessionProvider);
    ref.watch(storefrontCatalogRevisionProvider);
    return ref.read(reviewsServiceProvider).getMyReviewEligibility(productId);
  },
);

final ratingDistributionProvider =
    FutureProvider.autoDispose.family<Map<int, int>, String>(
  (ref, productId) async {
    ref.watch(storefrontCatalogRevisionProvider);
    return ref.read(reviewsServiceProvider).getProductRatingDistribution(productId);
  },
);
