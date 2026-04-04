import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/product_questions/models/product_qna_answer_eligibility.dart';
import 'package:ecommerce_app/features/product_questions/services/supabase_product_questions_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productQuestionsServiceProvider = Provider<SupabaseProductQuestionsService>(
  (ref) => SupabaseProductQuestionsService(ref.watch(supabaseClientProvider)),
);

final productQnaAnswerEligibilityProvider =
    FutureProvider.autoDispose.family<ProductQnaAnswerEligibility, String>(
  (ref, productId) {
    return ref.watch(productQuestionsServiceProvider).getMyProductQnaAnswerEligibility(productId);
  },
);
