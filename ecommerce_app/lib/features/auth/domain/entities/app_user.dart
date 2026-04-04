class AppUser {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
  });
}

