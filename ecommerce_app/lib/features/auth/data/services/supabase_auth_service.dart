import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:gotrue/gotrue.dart' show UserAttributes;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../auth_error_mapper.dart';
import '../models/profile_model.dart';

class SupabaseAuthService extends SupabaseServiceBase implements AuthRepository {
  SupabaseAuthService(
    super.client, {
    String authEmailRedirectUrl = '',
    String passwordResetRedirectUrl = '',
  })  : _authRedirect = authEmailRedirectUrl.trim(),
        _passwordResetRedirect = passwordResetRedirectUrl.trim();

  /// Sign-up / email-confirm PKCE callback.
  final String _authRedirect;

  /// Password-reset email link (separate from [_authRedirect] so we open set-password UI).
  final String _passwordResetRedirect;

  String? get _emailRedirectTo => _authRedirect.isEmpty ? null : _authRedirect;

  String? get _passwordResetRedirectTo =>
      _passwordResetRedirect.isEmpty ? null : _passwordResetRedirect;

  Future<AppUser> _toAppUser(User authUser) async {
    await _ensureProfileRow(authUser);
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
    );
    final profile = await _fetchProfile(authUser.id);
    return AppUser(
      id: authUser.id,
      email: authUser.email ?? '',
      fullName: profile?.fullName,
      avatarUrl: profile?.avatarUrl,
    );
  }

  @override
  Stream<AppUser?> watchAuthState() {
    return () async* {
      final initial = await _userIfEmailConfirmedOrSignOut(client.auth.currentUser);
      if (initial == null) {
        yield null;
      } else {
        yield await _toAppUser(initial);
      }

      await for (final event in client.auth.onAuthStateChange) {
        final raw = event.session?.user ?? client.auth.currentUser;
        final authUser = await _userIfEmailConfirmedOrSignOut(raw);
        if (authUser == null) {
          yield null;
          continue;
        }
        yield await _toAppUser(authUser);
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

    if (_isEmailPresentButUnconfirmed(authUser)) {
      try {
        await client.auth.signOut();
      } catch (_) {}
      throw const AuthException(
        'You must confirm your email address before signing in. '
        'Check your inbox for a confirmation link from us.',
        kind: AuthFailureKind.emailNotConfirmed,
      );
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
    );

    return _toAppUser(authUser);
  }

  @override
  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String userName = '',
  }) async {
    late final AuthResponse response;
    final trimmedName = userName.trim();
    final Map<String, dynamic>? meta =
        trimmedName.isEmpty ? null : <String, dynamic>{'full_name': trimmedName};
    try {
      response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _emailRedirectTo,
        data: meta,
      );
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: true);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw const AuthException('Sign-up failed: missing user.');
    }

    final session = response.session;
    if (_looksLikeExistingAccountSignUp(authUser, session)) {
      throw const AuthException(
        'An account with this email address already exists. '
        'Please sign in with your existing account.',
        kind: AuthFailureKind.accountExists,
      );
    }
    if (session != null && _isEmailPresentButUnconfirmed(authUser)) {
      try {
        await client.auth.signOut();
      } catch (_) {}
      throw const AuthException(
        'Please confirm your email address using the link we sent you, then sign in.',
        kind: AuthFailureKind.emailNotConfirmed,
      );
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
    );

    return _toAppUser(authUser);
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
    final confirmed = await _userIfEmailConfirmedOrSignOut(client.auth.currentUser);
    if (confirmed == null) return null;
    return _toAppUser(confirmed);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _passwordResetRedirectTo,
      );
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: false);
    }
  }

  @override
  Future<void> updatePasswordFromRecoverySession({required String newPassword}) async {
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw resolvePresentableAuthError(e, isSignUp: false);
    }
  }

  Future<ProfileModel?> _fetchProfile(String userId) async {
    try {
      final data = await client
          .from('profiles')
          .select('id, full_name, avatar_url, status, blocked_reason')
          .eq('id', userId)
          .single();

      return ProfileModel.fromJson(data);
    } catch (_) {
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
        'role': 'customer',
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
      } catch (_) {}
    }
    if (email != null && email.isNotEmpty) {
      try {
        await client.from('profiles').update({'email': email}).eq('id', authUser.id);
      } catch (_) {}
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

  bool _isEmailPresentButUnconfirmed(User u) {
    final email = u.email?.trim() ?? '';
    if (email.isEmpty) return false;
    final confirmed = u.emailConfirmedAt?.trim() ?? '';
    return confirmed.isEmpty;
  }

  Future<User?> _userIfEmailConfirmedOrSignOut(User? u) async {
    if (u == null) return null;
    if (_isEmailPresentButUnconfirmed(u)) {
      try {
        await client.auth.signOut();
      } catch (_) {}
      return null;
    }
    try {
      await ensureUserIsNotBlocked(
        client,
        userId: u.id,
        signOutIfBlocked: true,
      );
    } on AuthException {
      return null;
    }
    return u;
  }

  bool _looksLikeExistingAccountSignUp(User authUser, Session? session) {
    // Supabase can return no error for existing users to prevent email enumeration.
    // In that flow, the response commonly has no active session and no identities.
    if (session != null) return false;
    final identities = authUser.identities;
    return identities != null && identities.isEmpty;
  }
}
