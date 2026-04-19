import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseGoogleAuthService {
  FirebaseGoogleAuthService(
    this._firebaseAuth,
    this._supabase,
  );

  final FirebaseAuth _firebaseAuth;
  final sb.SupabaseClient _supabase;

  /// Firebase Google sign-in entry point for mobile and web.
  /// Android setup notes:
  /// - Add SHA-1 and SHA-256 of your signing keys in Firebase console.
  /// - Download updated google-services.json after adding SHA fingerprints.
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        return await _firebaseAuth.signInWithPopup(provider);
      }

      // Initialize google_sign_in so Android/iOS account selection stays explicit.
      await GoogleSignIn.instance.initialize();
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}

      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      return await _firebaseAuth.signInWithProvider(provider);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in failed. Please try again. $e',
      );
    }
  }

  Future<AppUser> signInToSupabaseFromGoogleUser({
    required UserCredential firebaseCredential,
  }) async {
    final firebaseUser = firebaseCredential.user;
    if (firebaseUser == null) {
      throw const sb.AuthException('Google sign-in did not return a valid Firebase user.');
    }
    final email = firebaseUser.email?.trim() ?? '';
    if (email.isEmpty) {
      throw const sb.AuthException('Google account does not have a valid email.');
    }
    await _supabase.auth.signOut();
    if (kIsWeb) {
      final rawCredential = firebaseCredential.credential;
      final oauth = rawCredential is OAuthCredential ? rawCredential : null;
      final googleIdToken = oauth?.idToken?.trim() ?? '';
      if (googleIdToken.isNotEmpty) {
        await _supabase.auth.signInWithIdToken(
          provider: sb.OAuthProvider.google,
          idToken: googleIdToken,
        );
      } else {
        final idToken = await firebaseUser.getIdToken(true);
        if (idToken == null || idToken.trim().isEmpty) {
          throw const sb.AuthException('Unable to get Google ID token from Firebase.');
        }
        final bridge = await _ensureGoogleBridgeIdentity(
          firebaseIdToken: idToken,
          firebaseUid: firebaseUser.uid.trim(),
          email: email,
          displayName: firebaseUser.displayName?.trim(),
          photoUrl: firebaseUser.photoURL?.trim(),
        );
        await _supabase.auth.signInWithPassword(
          email: bridge.email,
          password: bridge.password,
        );
      }
    } else {
      final idToken = await firebaseUser.getIdToken(true);
      if (idToken == null || idToken.trim().isEmpty) {
        throw const sb.AuthException('Unable to get Google ID token from Firebase.');
      }
      final bridge = await _ensureGoogleBridgeIdentity(
        firebaseIdToken: idToken,
        firebaseUid: firebaseUser.uid.trim(),
        email: email,
        displayName: firebaseUser.displayName?.trim(),
        photoUrl: firebaseUser.photoURL?.trim(),
      );
      await _supabase.auth.signInWithPassword(
        email: bridge.email,
        password: bridge.password,
      );
    }

    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      throw const sb.AuthException('Unable to create app session for Google user.');
    }

    await _upsertGoogleProfile(
      userId: authUser.id,
      firebaseUid: firebaseUser.uid,
      email: email,
      displayName: firebaseUser.displayName?.trim(),
      photoUrl: firebaseUser.photoURL?.trim(),
    );

    return AppUser(
      id: authUser.id,
      email: authUser.email ?? email,
      fullName: firebaseUser.displayName?.trim().isNotEmpty == true
          ? firebaseUser.displayName?.trim()
          : authUser.userMetadata?['full_name']?.toString(),
      avatarUrl: firebaseUser.photoURL?.trim(),
    );
  }

  Future<({String email, String password})> _ensureGoogleBridgeIdentity({
    required String firebaseIdToken,
    required String firebaseUid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final response = await _supabase.functions.invoke(
      'google-auth-bridge',
      body: <String, dynamic>{
        'firebase_id_token': firebaseIdToken,
        'firebase_uid': firebaseUid,
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final msg = data is Map ? (data['error']?.toString() ?? 'google_bridge_failed') : 'google_bridge_failed';
      throw sb.AuthException('Google bridge failed: $msg');
    }
    final data = response.data;
    if (data is! Map) {
      throw const sb.AuthException('Google bridge failed: invalid response.');
    }
    final bridgeEmail = data['email']?.toString().trim() ?? '';
    final bridgePassword = data['password']?.toString().trim() ?? '';
    if (bridgeEmail.isEmpty || bridgePassword.isEmpty) {
      throw const sb.AuthException('Google bridge failed: missing credentials.');
    }
    return (email: bridgeEmail, password: bridgePassword);
  }

  Future<void> _upsertGoogleProfile({
    required String userId,
    required String firebaseUid,
    required String email,
    required String? displayName,
    required String? photoUrl,
  }) async {
    final insertPayload = <String, dynamic>{
      'id': userId,
      'email': email,
      'full_name': (displayName == null || displayName.isEmpty) ? 'User' : displayName,
      'avatar_url': (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl,
      'firebase_uid': firebaseUid,
      'login_type': 'google',
      'role': 'customer',
    };
    final updatePayload = <String, dynamic>{
      'email': email,
      'full_name': insertPayload['full_name']!,
      'firebase_uid': firebaseUid,
      'login_type': 'google',
    };
    if (photoUrl != null && photoUrl.isNotEmpty) {
      updatePayload['avatar_url'] = photoUrl;
    }
    try {
      final rows = await _supabase
          .from('profiles')
          .update(updatePayload)
          .eq('id', userId)
          .select('id');
      if (rows.isNotEmpty) return;
    } catch (_) {}

    final existing = await _supabase.from('profiles').select('id').eq('id', userId).maybeSingle();
    if (existing != null) return;

    try {
      await _supabase.from('profiles').insert(insertPayload);
    } catch (_) {}
  }
}

final firebaseGoogleAuthServiceProvider = Provider<FirebaseGoogleAuthService>((ref) {
  return FirebaseGoogleAuthService(
    FirebaseAuth.instance,
    ref.read(supabaseClientProvider),
  );
});
