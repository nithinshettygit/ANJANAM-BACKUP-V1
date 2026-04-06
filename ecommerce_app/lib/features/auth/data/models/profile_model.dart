class ProfileModel {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String status;
  final String? blockedReason;

  const ProfileModel({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.status = 'active',
    this.blockedReason,
  });

  bool get isBlocked => status.trim().toLowerCase() == 'blocked';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json['id'] ?? '').toString(),
      fullName: json['full_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      status: (json['status'] ?? 'active').toString(),
      blockedReason: json['blocked_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'status': status,
      'blocked_reason': blockedReason,
    };
  }
}

