class ReviewEligibility {
  final bool signedIn;
  final bool eligible;
  final bool hasReview;

  const ReviewEligibility({
    required this.signedIn,
    required this.eligible,
    required this.hasReview,
  });

  factory ReviewEligibility.fromJson(Map<String, dynamic> json) {
    return ReviewEligibility(
      signedIn: json['signed_in'] == true,
      eligible: json['eligible'] == true,
      hasReview: json['has_review'] == true,
    );
  }
}
