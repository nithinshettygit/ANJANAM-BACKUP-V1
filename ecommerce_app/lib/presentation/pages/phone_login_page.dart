import 'dart:async';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/data/services/firebase_phone_auth_service.dart';
import 'package:ecommerce_app/features/auth/state/auth_local_session_store.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecommerce_app/firebase_options.dart';

final firebasePhoneAuthServiceProvider = Provider<FirebasePhoneAuthService>((ref) {
  return FirebasePhoneAuthService(
    FirebaseAuth.instance,
    ref.read(supabaseClientProvider),
  );
});

class PhoneLoginPage extends ConsumerStatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  ConsumerState<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends ConsumerState<PhoneLoginPage> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  String? _verificationId;
  ConfirmationResult? _confirmationResult;
  int? _resendToken;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String? _validatePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return 'Enter a valid phone number';
    return null;
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    if (kIsWeb && Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {}
    }
    if (kIsWeb && Firebase.apps.isEmpty) {
      _show('Phone login is unavailable right now. Please refresh and try again.');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    final err = _validatePhone(phone);
    if (err != null) {
      _show(err);
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      final result = await ref.read(firebasePhoneAuthServiceProvider).startOtp(
            phoneNumber: phone,
            forceResendingToken: isResend ? _resendToken : null,
          );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _verificationId = result.verificationId ?? _verificationId;
        _confirmationResult = result.confirmationResult ?? _confirmationResult;
        _resendToken = result.resendToken ?? _resendToken;
      });
      _startResendCooldown();
      _otpFocus.requestFocus();
      _show('OTP sent successfully');
    } catch (e) {
      _show('Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) {
      _show('Enter valid 6-digit OTP');
      return;
    }
    setState(() => _isVerifyingOtp = true);
    try {
      final credential = await ref.read(firebasePhoneAuthServiceProvider).verifyOtp(
            smsCode: code,
            verificationId: _verificationId,
            confirmationResult: _confirmationResult,
          );
      final phone = credential.user?.phoneNumber ?? _phoneCtrl.text.trim();
      final firebaseUid = credential.user?.uid;
      if (firebaseUid == null || firebaseUid.isEmpty) {
        throw Exception('Phone verification failed. Please retry.');
      }
      final appUser = await ref.read(firebasePhoneAuthServiceProvider).signInToSupabaseFromPhoneUser(
            phoneNumber: phone,
            firebaseUid: firebaseUid,
          );
      await ref.read(authLocalSessionStoreProvider).save(
            userId: appUser.id,
            loginType: LoginType.phone,
          );
      if (!mounted) return;
      _show('Login successful');
      goToStorefrontAfterCustomerAuth(ref, context);
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase().trim();
      if (code == 'code-expired') {
        _show('OTP expired. Please tap Resend OTP and use the latest code.');
      } else if (code == 'invalid-verification-code') {
        _show('Invalid OTP. Enter the latest code received on your phone.');
      } else if (code == 'too-many-requests') {
        _show('Too many OTP attempts. Please wait a few minutes and retry.');
      } else {
        _show('OTP verification failed (${e.code}). ${e.message ?? ''}'.trim());
      }
    } catch (e) {
      _show('OTP verification failed: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+91XXXXXXXXXX',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSendingOtp || _isVerifyingOtp ? null : () => _sendOtp(),
                  child: Text(_isSendingOtp ? 'Sending OTP...' : 'Send OTP'),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: _otpCtrl,
                  focusNode: _otpFocus,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isVerifyingOtp || _isSendingOtp ? null : _verifyOtp,
                    child: Text(_isVerifyingOtp ? 'Verifying...' : 'Verify OTP'),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: (_resendSeconds == 0 && !_isSendingOtp && !_isVerifyingOtp)
                      ? () => _sendOtp(isResend: true)
                      : null,
                  child: Text(
                    _resendSeconds == 0 ? 'Resend OTP' : 'Resend OTP in ${_resendSeconds}s',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
