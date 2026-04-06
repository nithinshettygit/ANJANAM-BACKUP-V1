import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps a route that requires a signed-in user. Unauthenticated users are
/// sent to [loginRouteName] (replace) so they cannot pop back without signing in.
class AuthGuard extends ConsumerStatefulWidget {
  static const String loginRouteName = '/login';

  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  bool _authListenAttached = false;
  bool _statusCheckInFlight = false;
  bool _handledBlockedAccount = false;

  void _redirectToLoginIfNeeded(AsyncValue<AppUser?> session) {
    if (!mounted) return;
    if (session.isLoading) return;
    if (session.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AuthGuard.loginRouteName);
      });
      return;
    }
    if (session.hasValue && session.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AuthGuard.loginRouteName);
      });
      return;
    }
    if (session.hasValue && session.value != null) {
      _verifyActiveStatusAndRedirectIfBlocked();
    }
  }

  Future<void> _verifyActiveStatusAndRedirectIfBlocked() async {
    if (!mounted || _statusCheckInFlight || _handledBlockedAccount) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _statusCheckInFlight = true;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('status, blocked_reason')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      if (!isBlockedStatusValue(row?['status']?.toString())) return;

      _handledBlockedAccount = true;
      final message = blockedAccountMessageWithReason(
        row?['blocked_reason']?.toString(),
      );
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AuthGuard.loginRouteName,
        (route) => false,
      );
    } catch (_) {
      // Ignore transient lookup failures and keep guard behavior unchanged.
    } finally {
      _statusCheckInFlight = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authListenAttached) return;
    _authListenAttached = true;
    ref.listenManual<AsyncValue<AppUser?>>(
      authSessionProvider,
      (previous, next) => _redirectToLoginIfNeeded(next),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        _verifyActiveStatusAndRedirectIfBlocked();
        return widget.child;
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
