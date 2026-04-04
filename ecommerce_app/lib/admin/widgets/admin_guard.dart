import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import '../providers/is_admin_provider.dart';

class AdminGuard extends ConsumerWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      data: (user) {
        if (user == null) {
          return const _GuardRedirect(
            route: '/login',
            message: 'Redirecting to login...',
          );
        }
        final isAdminAsync = ref.watch(isAdminProvider);
        return isAdminAsync.when(
          data: (isAdmin) {
            if (!isAdmin) {
              return const _GuardRedirect(
                route: '/',
                message: 'Admin access required. Redirecting...',
              );
            }
            return child;
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _GuardRedirect(
            route: '/',
            message: 'Unable to verify admin access. Redirecting...',
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _GuardRedirect(
        route: '/login',
        message: 'Authentication error. Redirecting...',
      ),
    );
  }
}

class _GuardRedirect extends StatefulWidget {
  final String route;
  final String message;

  const _GuardRedirect({
    required this.route,
    required this.message,
  });

  @override
  State<_GuardRedirect> createState() => _GuardRedirectState();
}

class _GuardRedirectState extends State<_GuardRedirect> {
  bool _redirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(widget.route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
