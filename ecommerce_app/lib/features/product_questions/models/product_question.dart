import 'product_answer.dart';

class ProductQuestion {
  final String id;
  final String userId;
  final String question;
  final DateTime createdAt;
  final String authorDisplayName;
  final List<ProductAnswer> answers;

  const ProductQuestion({
    required this.id,
    required this.userId,
    required this.question,
    required this.createdAt,
    required this.authorDisplayName,
    required this.answers,
  });

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  factory ProductQuestion.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    final answers = <ProductAnswer>[];
    if (rawAnswers is List) {
      for (final e in rawAnswers) {
        if (e is Map) {
          answers.add(ProductAnswer.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    answers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ProductQuestion(
      id: json['id'].toString(),
      userId: (json['user_id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      createdAt: _parseTs(json['created_at']),
      authorDisplayName: (json['author_display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['author_display_name'] as String).trim()
          : 'Customer',
      answers: answers,
    );
  }
}
