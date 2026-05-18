import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:ecommerce_app/core/auth/blocked_account_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import '../providers/is_admin_provider.dart';

class AdminGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  ConsumerState<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends ConsumerState<AdminGuard> {
  bool _blockedCheckDone = false;

  Future<void> _checkBlockedAdmin() async {
    if (_blockedCheckDone) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _blockedCheckDone = true;
    final detection = await fetchOwnAccountRestriction(
      Supabase.instance.client,
      userId: userId,
    );
    if (!mounted || detection == null) return;
    await ref.read(blockedAccountGateProvider).presentRestricted(detection: detection);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      data: (user) {
        if (user == null) {
          return const _GuardRedirect(
            route: '/login',
            message: 'Redirecting to login...',
          );
        }
        _checkBlockedAdmin();
        final isAdminAsync = ref.watch(isAdminProvider);
        return isAdminAsync.when(
          data: (isAdmin) {
            if (!isAdmin) {
              return const _GuardRedirect(
                route: '/',
                message: 'Admin access required. Redirecting...',
              );
            }
            return widget.child;
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
