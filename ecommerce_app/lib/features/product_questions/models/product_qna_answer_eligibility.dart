class ProductQnaAnswerEligibility {
  final bool isAdmin;
  final bool canAnswerAsVerifiedBuyer;

  const ProductQnaAnswerEligibility({
    required this.isAdmin,
    required this.canAnswerAsVerifiedBuyer,
  });

  bool get canAnswerAny => isAdmin || canAnswerAsVerifiedBuyer;

  factory ProductQnaAnswerEligibility.fromRpc(dynamic raw) {
    final m = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    return ProductQnaAnswerEligibility(
      isAdmin: m['is_admin'] == true,
      canAnswerAsVerifiedBuyer: m['can_answer_as_verified_buyer'] == true,
    );
  }
}
