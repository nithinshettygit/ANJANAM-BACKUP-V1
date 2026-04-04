import 'product_answer.dart';

/// Admin list row: question + product title + optional answers (with names resolved client-side).
class AdminProductQuestionRow {
  final String id;
  final String productId;
  final String productTitle;
  final String userId;
  final String question;
  final DateTime createdAt;
  final bool isApproved;
  final String askerDisplayName;
  final List<ProductAnswer> answers;

  const AdminProductQuestionRow({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.userId,
    required this.question,
    required this.createdAt,
    required this.isApproved,
    required this.askerDisplayName,
    required this.answers,
  });
}
