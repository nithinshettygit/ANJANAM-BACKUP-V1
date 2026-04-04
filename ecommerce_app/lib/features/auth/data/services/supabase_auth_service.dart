import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../auth_error_mapper.dart';
import '../models/profile_model.dart';

class SupabaseAuthService extends SupabaseServiceBase implements AuthRepository {
  SupabaseAuthService(super.client);

  @override
  Stream<AppUser?> watchAuthState() {
    return () async* {
      // Emit current session immediately so route guards work right after refresh/login.
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        yield null;
      } else {
        final profile = await _fetchProfile(currentUser.id);
        yield AppUser(
          id: currentUser.id,
          email: currentUser.email ?? '',
          fullName: profile?.fullName,
          avatarUrl: profile?.avatarUrl,
        );
      }

      await for (final event in client.auth.onAuthStateChange) {
        final authUser = event.session?.user ?? client.auth.currentUser;
        if (authUser == null) {
          yield null;
          continue;
        }
        final profile = await _fetchProfile(authUser.id);
        yield AppUser(
          id: authUser.id,
          email: authUser.email ?? '',
          fullName: profile?.fullName,
          avatarUrl: profile?.avatarUrl,
        );
      }
    }();
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    late final AuthResponse response;
    try {
      response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: false);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw const AuthException('Sign-in failed: missing user.');
    }

    await _ensureProfileRow(authUser);

    final profile = await _fetchProfile(authUser.id);
    return AppUser(
      id: authUser.id,
      email: authUser.email ?? '',
      fullName: profile?.fullName,
      avatarUrl: profile?.avatarUrl,
    );
  }

  @override
  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    late final AuthResponse response;
    try {
      response = await client.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: true);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw const AuthException('Sign-up failed: missing user.');
    }

    await _ensureProfileRow(authUser);

    final profile = await _fetchProfile(authUser.id);
    return AppUser(
      id: authUser.id,
      email: authUser.email ?? '',
      fullName: profile?.fullName,
      avatarUrl: profile?.avatarUrl,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: false);
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return null;

    await _ensureProfileRow(authUser);

    final profile = await _fetchProfile(authUser.id);
    return AppUser(
      id: authUser.id,
      email: authUser.email ?? '',
      fullName: profile?.fullName,
      avatarUrl: profile?.avatarUrl,
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: false);
    }
  }

  Future<ProfileModel?> _fetchProfile(String userId) async {
    try {
      // Adjust selected columns to match your `profiles` table schema.
      final data = await client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', userId)
          .single();

      return ProfileModel.fromJson(data);
    } catch (_) {
      // Profile row might not exist yet; auth still works.
      return null;
    }
  }

  Future<void> _ensureProfileRow(User authUser) async {
    final email = authUser.email;
    final Map<String, dynamic> emailField =
        (email != null && email.isNotEmpty) ? <String, dynamic>{'email': email} : <String, dynamic>{};
    try {
      await client.from('profiles').insert({
        'id': authUser.id,
        'full_name': _deriveDisplayName(authUser),
        'avatar_url': null,
        'role': 'user',
        ...emailField,
      });
    } catch (_) {
      try {
        await client.from('profiles').insert({
          'id': authUser.id,
          'full_name': _deriveDisplayName(authUser),
          'avatar_url': null,
          ...emailField,
        });
      } catch (_) {
        // Row may already exist or insert may be denied by policy; ignore safely.
      }
    }
    if (email != null && email.isNotEmpty) {
      try {
        await client.from('profiles').update({'email': email}).eq('id', authUser.id);
      } catch (_) {
        // Column may not exist on older DBs; ignore.
      }
    }
  }

  String _deriveDisplayName(User authUser) {
    final fromMeta = authUser.userMetadata?['full_name']?.toString().trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final email = authUser.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }
}

