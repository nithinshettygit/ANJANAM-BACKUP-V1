import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/catalog/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackendDebugPage extends ConsumerStatefulWidget {
  const BackendDebugPage({super.key});

  @override
  ConsumerState<BackendDebugPage> createState() => _BackendDebugPageState();
}

class _BackendDebugPageState extends ConsumerState<BackendDebugPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _status = 'Idle';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductsTest() async {
    setState(() => _status = 'Fetching products...');
    try {
      final rows = await ref.read(supabaseClientProvider).from('products').select(
            'id, title, description, price, currency, image_urls, category, inventory_count, created_at',
          );

      final products = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList();

      debugPrint('---- PRODUCTS TEST ----');
      debugPrint('Fetched ${products.length} products');
      for (final p in products) {
        debugPrint(
          'Product: id=${p.id}, title=${p.title}, image_urls_type=${p.imageUrls.runtimeType}, '
          'first_image=${p.imageUrls.isNotEmpty ? p.imageUrls.first : 'none'}',
        );
      }
      debugPrint('-----------------------');

      setState(() => _status = 'Products fetched: ${products.length}. Check console logs.');
    } catch (e) {
      debugPrint('Products test failed: $e');
      setState(() => _status = 'Products test failed: $e');
    }
  }

  Future<void> _runAuthTests() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _status = 'Enter email and password.');
      return;
    }

    setState(() => _status = 'Running auth tests...');
    final authRepo = ref.read(authRepositoryProvider);

    try {
      // Sign-up may fail if user exists; we continue with sign-in.
      try {
        await authRepo.signUpWithEmailAndPassword(email: email, password: password);
        debugPrint('Sign-up success for $email');
      } catch (e) {
        debugPrint('Sign-up skipped/failed (expected if user exists): $e');
      }

      final user = await authRepo.signInWithEmailAndPassword(email: email, password: password);
      debugPrint('Sign-in success: user_id=${user.id}');

      final sessionUserId =
          ref.read(supabaseClientProvider).auth.currentSession?.user.id ?? 'null';
      debugPrint('Current session user id: $sessionUserId');

      setState(() => _status = 'Auth tests success. user_id=$sessionUserId');
    } catch (e) {
      debugPrint('Auth tests failed: $e');
      setState(() => _status = 'Auth tests failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final sessionUser = session.when(
      data: (user) => user,
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Backend Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Text('Current session: ${sessionUser?.id ?? 'signed out'}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchProductsTest,
              child: const Text('Test Products Fetch'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _runAuthTests,
              child: const Text('Test Auth (Sign Up + Sign In)'),
            ),
          ],
        ),
      ),
    );
  }
}

