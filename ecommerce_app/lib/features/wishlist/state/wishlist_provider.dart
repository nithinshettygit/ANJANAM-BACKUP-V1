import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/domain/entities/app_user.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kGuestWishlistKey = 'guest_wishlist_product_ids';

/// Loads / syncs wishlist: **Supabase** when signed in, **SharedPreferences** when guest.
/// Guest items are merged into the server list on first load after login.
class WishlistController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final auth = ref.watch(authSessionProvider);
    if (auth.isLoading) {
      return _guestIds();
    }
    return _loadForSession(auth.value);
  }

  Future<Set<String>> _guestIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kGuestWishlistKey) ?? []).toSet();
  }

  Future<void> _persistGuest(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final list = ids.toList()..sort();
    if (list.isEmpty) {
      await prefs.remove(_kGuestWishlistKey);
    } else {
      await prefs.setStringList(_kGuestWishlistKey, list);
    }
  }

  Future<Set<String>> _loadForSession(AppUser? session) async {
    final guest = await _guestIds();
    if (session == null) {
      return guest;
    }

    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .from('wishlist_items')
        .select('product_id')
        .eq('user_id', session.id);
    var server = (rows as List)
        .map((e) => e['product_id'].toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (guest.isNotEmpty) {
      for (final pid in guest) {
        try {
          await client.from('wishlist_items').insert({
            'user_id': session.id,
            'product_id': pid,
          });
        } catch (_) {
          // Duplicate key or invalid product (e.g. deleted) — skip.
        }
      }
      await _persistGuest({});
      server = {...server, ...guest};
    }

    return server;
  }

  Future<void> toggle(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return;

    final session = ref.read(authSessionProvider).value;
    late final Set<String> before;
    if (state.hasValue) {
      before = Set<String>.from(state.requireValue);
    } else {
      try {
        before = await future;
      } catch (_) {
        before = {};
      }
    }

    final had = before.contains(id);
    final next = Set<String>.from(before);
    if (had) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = AsyncData(next);

    try {
      if (session != null) {
        final client = ref.read(supabaseClientProvider);
        if (had) {
          await client
              .from('wishlist_items')
              .delete()
              .eq('user_id', session.id)
              .eq('product_id', id);
        } else {
          await client.from('wishlist_items').insert({
            'user_id': session.id,
            'product_id': id,
          });
        }
      } else {
        await _persistGuest(next);
      }
    } on Object catch (e, st) {
      state = AsyncData(before);
      Error.throwWithStackTrace(e, st);
    }
  }
}

final wishlistControllerProvider =
    AsyncNotifierProvider<WishlistController, Set<String>>(WishlistController.new);

/// Sync read for widgets: current ids, or empty while the async notifier is still loading.
final wishlistProvider = Provider<Set<String>>((ref) {
  return ref.watch(wishlistControllerProvider).value ?? const <String>{};
});
