import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
