import '../entities/app_user.dart';

/// Auth repository interface (no Supabase/HTTP logic here).
abstract class AuthRepository {
  Stream<AppUser?> watchAuthState();

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String userName = '',
  });

  Future<void> signOut();

  Future<AppUser?> getCurrentUser();

  Future<void> sendPasswordResetEmail({required String email});

  /// After opening the password-recovery link (recovery session). Updates password then caller should sign out.
  Future<void> updatePasswordFromRecoverySession({required String newPassword});
}
