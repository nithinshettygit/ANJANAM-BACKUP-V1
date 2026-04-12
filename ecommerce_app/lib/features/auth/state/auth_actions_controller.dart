import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_session_provider.dart';

class AuthActionsController extends AsyncNotifier<void> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final client = ref.read(supabaseClientProvider);
    try {
      await client.auth.signOut();
    } catch (_) {
      // Clear any broken persisted session (e.g. invalid refresh token on Android)
      // so the new password sign-in is not racing with stale local auth storage.
    }
    final result = await AsyncValue.guard(
      () => _repo.signInWithEmailAndPassword(email: email, password: password),
    );
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    state = const AsyncData(null);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String userName = '',
  }) async {
    state = const AsyncLoading();
    final client = ref.read(supabaseClientProvider);
    try {
      await client.auth.signOut();
    } catch (_) {}
    final result = await AsyncValue.guard(
      () => _repo.signUpWithEmailAndPassword(
            email: email,
            password: password,
            userName: userName,
          ),
    );
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    state = const AsyncData(null);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _repo.signOut());
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    state = const AsyncData(null);
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repo.sendPasswordResetEmail(email: email),
    );
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    state = const AsyncData(null);
  }

  Future<void> updatePasswordFromRecoverySession({
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repo.updatePasswordFromRecoverySession(newPassword: newPassword),
    );
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      throw result.error!;
    }
    state = const AsyncData(null);
  }
}

final authActionsProvider =
    AsyncNotifierProvider<AuthActionsController, void>(
  () => AuthActionsController(),
);
