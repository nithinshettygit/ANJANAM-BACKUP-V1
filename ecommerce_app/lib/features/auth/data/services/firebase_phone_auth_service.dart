import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_user.dart';

class PhoneOtpStartResult {
  const PhoneOtpStartResult({
    this.verificationId,
    this.resendToken,
    this.confirmationResult,
  });

  final String? verificationId;
  final int? resendToken;
  final ConfirmationResult? confirmationResult;
}

class FirebasePhoneAuthService {
  String _buildClientNonce() {
    final r = Random.secure();
    final bytes = List<int>.generate(24, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  FirebasePhoneAuthService(
    this._firebaseAuth,
    this._supabase,
  );

  final FirebaseAuth _firebaseAuth;
  final SupabaseClient _supabase;

  String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('00')) {
      digits = '+${digits.substring(2)}';
    }
    if (!digits.startsWith('+')) {
      if (digits.length == 10) return '+91$digits';
      return '+$digits';
    }
    return digits;
  }

  Future<PhoneOtpStartResult> startOtp({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final normalized = normalizePhone(phoneNumber);
    if (kIsWeb) {
      final result = await _firebaseAuth.signInWithPhoneNumber(normalized);
      return PhoneOtpStartResult(confirmationResult: result);
    }

    final completer = Completer<PhoneOtpStartResult>();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: normalized,
      timeout: timeout,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async {
        if (!completer.isCompleted) {
          completer.complete(const PhoneOtpStartResult());
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpStartResult(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpStartResult(verificationId: verificationId));
        }
      },
    );
    return completer.future;
  }

  Future<UserCredential> verifyOtp({
    required String smsCode,
    String? verificationId,
    ConfirmationResult? confirmationResult,
  }) async {
    if (kIsWeb) {
      if (confirmationResult == null) {
        throw FirebaseAuthException(
          code: 'missing-confirmation',
          message: 'Missing web OTP confirmation result.',
        );
      }
      return confirmationResult.confirm(smsCode);
    }
    if (verificationId == null || verificationId.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Missing verification id for OTP.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<AppUser> signInToSupabaseFromPhoneUser({
    required String phoneNumber,
    required String firebaseUid,
  }) async {
    final phone = normalizePhone(phoneNumber);
    await _supabase.auth.signOut();
    final bridge = await _ensurePhoneBridgeIdentity();
    await _supabase.auth.setSession(bridge.refreshToken);
    if (kDebugMode) {
      debugPrint(
        'Phone login: Supabase session present=${_supabase.auth.currentSession != null}',
      );
    }
    if (_supabase.auth.currentSession == null) {
      throw const AuthException('Session expired, please login again');
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Unable to establish app session for phone user.');
    }

    await _syncProfileForPhoneAuth(
      userId: user.id,
      phone: phone,
      firebaseUid: firebaseUid,
    );

    return AppUser(
      id: user.id,
      email: '',
      fullName: user.userMetadata?['full_name']?.toString(),
    );
  }

  Future<AppUser?> resumePhoneSessionIfAvailable() async {
    if (_supabase.auth.currentUser != null) {
      final user = _supabase.auth.currentUser!;
      return AppUser(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name']?.toString(),
      );
    }

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;
    final phone = firebaseUser.phoneNumber;
    if (phone == null || phone.trim().isEmpty) return null;
    final firebaseUid = firebaseUser.uid.trim();
    if (firebaseUid.isEmpty) return null;

    return signInToSupabaseFromPhoneUser(
      phoneNumber: phone,
      firebaseUid: firebaseUid,
    );
  }

  Future<({String refreshToken})> _ensurePhoneBridgeIdentity() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('Phone session missing. Please verify OTP again.');
    }
    final idToken = await firebaseUser.getIdToken(true);
    if (kDebugMode) {
      debugPrint('Phone OTP verify: Firebase ID token received=${idToken != null && idToken.isNotEmpty}');
    }
    final response = await _supabase.functions.invoke(
      'phone-auth-bridge',
      body: <String, dynamic>{
        'id_token': idToken,
        'client_nonce': _buildClientNonce(),
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final msg = data is Map ? (data['error']?.toString() ?? 'phone_bridge_failed') : 'phone_bridge_failed';
      throw AuthException('Phone bridge failed: $msg');
    }
    final data = response.data;
    if (data is! Map) {
      throw const AuthException('Phone bridge failed: invalid response.');
    }
    final refreshToken = data['refresh_token']?.toString().trim() ?? '';
    if (refreshToken.isEmpty) {
      throw const AuthException('Phone bridge failed: missing session token.');
    }
    return (refreshToken: refreshToken);
  }

  Future<void> _syncProfileForPhoneAuth({
    required String userId,
    required String phone,
    required String firebaseUid,
  }) async {
    final nameRow = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();
    final existingName = nameRow?['full_name']?.toString().trim() ?? '';
    final fullName = existingName.isNotEmpty ? existingName : 'User';
    final insertPayload = <String, dynamic>{
      'id': userId,
      'full_name': fullName,
      'role': 'customer',
      'phone': phone,
      'firebase_uid': firebaseUid,
      'login_type': 'phone',
    };
    final updatePayload = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'firebase_uid': firebaseUid,
      'login_type': 'phone',
    };
    try {
      final rows = await _supabase
          .from('profiles')
          .update(updatePayload)
          .eq('id', userId)
          .select('id');
      if (rows.isNotEmpty) return;
    } catch (_) {}

    final idRow = await _supabase.from('profiles').select('id').eq('id', userId).maybeSingle();
    if (idRow != null) return;

    try {
      await _supabase.from('profiles').insert(insertPayload);
    } catch (_) {}
  }

}
