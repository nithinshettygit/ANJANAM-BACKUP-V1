import 'dart:convert';

import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:ecommerce_app/features/product_questions/models/admin_product_question_row.dart';
import 'package:ecommerce_app/features/product_questions/models/product_answer.dart';
import 'package:ecommerce_app/features/product_questions/models/product_qna_answer_eligibility.dart';
import 'package:ecommerce_app/features/product_questions/models/product_question.dart';
import 'package:postgrest/postgrest.dart';

class SupabaseProductQuestionsService extends SupabaseServiceBase {
  SupabaseProductQuestionsService(super.client);

  static const int pageSize = 20;

  static String _displayName(String? fullName) {
    final t = fullName?.trim();
    if (t == null || t.isEmpty) return 'Customer';
    return t;
  }

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Storefront: approved questions, newest first, with nested answers (RPC — single round-trip).
  Future<({List<ProductQuestion> items, bool hasMore})> fetchProductQuestions({
    required String productId,
    required int offset,
    int limit = pageSize,
  }) async {
    final take = limit.clamp(1, 50) + 1;
    final raw = await guard(
      () => client.rpc(
        'fetch_product_questions_page',
        params: <String, dynamic>{
          'p_product_id': productId,
          'p_limit': take,
          'p_offset': offset,
        },
      ),
    );
    final list = _parseRpcQuestionList(raw);
    var hasMore = list.length > limit;
    final items = hasMore ? list.sublist(0, limit) : list;
    return (items: items, hasMore: hasMore);
  }

  List<ProductQuestion> _parseRpcQuestionList(dynamic raw) {
    if (raw == null) return [];
    List<dynamic> list;
    if (raw is String) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          list = decoded;
        } else {
          return [];
        }
      } catch (_) {
        return [];
      }
    } else if (raw is List) {
      list = raw;
    } else {
      return [];
    }
    return list
        .map((e) {
          if (e is! Map) return null;
          return ProductQuestion.fromJson(Map<String, dynamic>.from(e));
        })
        .whereType<ProductQuestion>()
        .toList();
  }

  Future<void> askProductQuestion({
    required String productId,
    required String question,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthException('Sign in to ask a question.');
    }
    final q = question.trim();
    if (q.isEmpty) {
      throw const ValidationException('Please enter a question.');
    }
    if (q.length > 2000) {
      throw const ValidationException('Question must be at most 2,000 characters.');
    }
    try {
      await client.from('product_questions').insert({
        'product_id': productId,
        'user_id': uid,
        'question': q,
      });
    } on PostgrestException catch (e) {
      _mapPostgrest(e, fallback: 'Could not post your question.');
    }
  }

  /// Storefront or admin: server decides seller vs verified buyer (no client trust).
  Future<void> submitProductAnswer({
    required String questionId,
    required String answer,
  }) async {
    final a = answer.trim();
    if (a.isEmpty) {
      throw const ValidationException('Please enter an answer.');
    }
    if (a.length > 2000) {
      throw const ValidationException('Answer must be at most 2,000 characters.');
    }
    try {
      await client.rpc(
        'submit_product_answer',
        params: <String, dynamic>{
          'p_question_id': questionId,
          'p_answer': a,
        },
      );
    } on PostgrestException catch (e) {
      _mapSubmitAnswerException(e);
    }
  }

  Future<ProductQnaAnswerEligibility> getMyProductQnaAnswerEligibility(String productId) async {
    final raw = await guard(
      () => client.rpc(
        'get_my_product_qna_answer_eligibility',
        params: <String, dynamic>{'p_product_id': productId},
      ),
    );
    return ProductQnaAnswerEligibility.fromRpc(raw);
  }

  Future<void> updateProductAnswer({
    required String answerId,
    required String answer,
  }) async {
    final a = answer.trim();
    if (a.isEmpty) {
      throw const ValidationException('Please enter an answer.');
    }
    if (a.length > 2000) {
      throw const ValidationException('Answer must be at most 2,000 characters.');
    }
    try {
      await client.from('product_answers').update({'answer': a}).eq('id', answerId);
    } on PostgrestException catch (e) {
      _mapPostgrest(e, fallback: 'Could not update answer.');
    }
  }

  Future<void> deleteProductAnswer(String answerId) async {
    try {
      await client.from('product_answers').delete().eq('id', answerId);
    } on PostgrestException catch (e) {
      _mapPostgrest(e, fallback: 'Could not delete answer.');
    }
  }

  Future<void> deleteProductQuestion(String questionId) async {
    try {
      await client.from('product_questions').delete().eq('id', questionId);
    } on PostgrestException catch (e) {
      _mapPostgrest(e, fallback: 'Could not delete question.');
    }
  }

  Future<void> setQuestionApproved({
    required String questionId,
    required bool approved,
  }) async {
    try {
      await client.from('product_questions').update({'is_approved': approved}).eq('id', questionId);
    } on PostgrestException catch (e) {
      _mapPostgrest(e, fallback: 'Could not update question.');
    }
  }

  /// Admin: paginated, all moderation states. Two queries (questions + profiles) to avoid N+1.
  Future<({List<AdminProductQuestionRow> items, bool hasMore})> fetchAdminProductQuestionsPage({
    required int offset,
    int limit = pageSize,
  }) async {
    final take = limit.clamp(1, 50) + 1;
    final end = offset + take - 1;
    final rows = await guard(
      () => client
          .from('product_questions')
          .select(
            'id, product_id, user_id, question, created_at, is_approved, '
            'products(title), '
            'product_answers(id, user_id, answer, is_admin, is_verified_purchase, created_at)',
          )
          .order('created_at', ascending: false)
          .range(offset, end),
    ) as List<dynamic>;

    final cast = rows.cast<Map<String, dynamic>>();
    var hasMore = cast.length > limit;
    final slice = hasMore ? cast.sublist(0, limit) : cast;

    final userIds = <String>{};
    for (final row in slice) {
      final uid = row['user_id']?.toString();
      if (uid != null && uid.isNotEmpty) userIds.add(uid);
      final answers = row['product_answers'];
      if (answers is List) {
        for (final a in answers) {
          if (a is Map) {
            final aid = a['user_id']?.toString();
            if (aid != null && aid.isNotEmpty) userIds.add(aid);
          }
        }
      }
    }

    final names = await _fetchProfileNames(userIds.toList());

    final out = <AdminProductQuestionRow>[];
    for (final row in slice) {
      final product = row['products'];
      String title = 'Product';
      if (product is Map) {
        final t = product['title']?.toString().trim();
        if (t != null && t.isNotEmpty) title = t;
      }
      final qid = row['user_id']?.toString() ?? '';
      final rawAnswers = row['product_answers'];
      final answerList = <ProductAnswer>[];
      if (rawAnswers is List) {
        for (final e in rawAnswers) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final aid = m['user_id']?.toString() ?? '';
          answerList.add(
            ProductAnswer.fromJson({
              ...m,
              'author_display_name': names[aid],
            }),
          );
        }
      }
      answerList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      out.add(
        AdminProductQuestionRow(
          id: row['id'].toString(),
          productId: row['product_id'].toString(),
          productTitle: title,
          userId: qid,
          question: (row['question'] ?? '').toString(),
          createdAt: _parseTs(row['created_at']),
          isApproved: row['is_approved'] == true,
          askerDisplayName: _displayName(names[qid]),
          answers: answerList,
        ),
      );
    }

    return (items: out, hasMore: hasMore);
  }

  Future<Map<String, String>> _fetchProfileNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    final data = await guard(
      () => client.from('profiles').select('id, full_name').inFilter('id', ids),
    ) as List<dynamic>;
    final map = <String, String>{};
    for (final row in data.cast<Map<String, dynamic>>()) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = row['full_name']?.toString() ?? '';
    }
    return map;
  }

  void _mapSubmitAnswerException(PostgrestException e) {
    final m = e.message.toLowerCase();
    if (m.contains('not_authenticated')) {
      throw const AuthException('Sign in to post an answer.');
    }
    if (m.contains('answer_required')) {
      throw const ValidationException('Please enter an answer.');
    }
    if (m.contains('answer_too_long')) {
      throw const ValidationException('Answer must be at most 2,000 characters.');
    }
    if (m.contains('question_not_found')) {
      throw const ValidationException('This question is no longer available.');
    }
    if (m.contains('question_not_visible')) {
      throw const ValidationException('This question is not available for answers.');
    }
    if (m.contains('product_not_available')) {
      throw const ValidationException('This product is not available.');
    }
    if (m.contains('not_eligible_to_answer')) {
      throw const ValidationException(
        'Only the seller or verified buyers who received this product can answer.',
      );
    }
    _mapPostgrest(e, fallback: 'Could not post answer.');
  }

  void _mapPostgrest(PostgrestException e, {required String fallback}) {
    final code = e.code;
    final msg = e.message.toLowerCase();
    if (code == '42501' || msg.contains('permission') || msg.contains('policy')) {
      throw const AuthException('You do not have permission for this action.');
    }
    if (msg.contains('foreign key') || msg.contains('violates foreign key')) {
      throw const ValidationException('Product or account is not available.');
    }
    throw RepositoryException(e.message.isNotEmpty ? e.message : fallback);
  }
}
