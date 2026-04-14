import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginType { email, phone, google }

class LocalAuthSessionSnapshot {
  const LocalAuthSessionSnapshot({
    required this.userId,
    required this.loginType,
  });

  final String userId;
  final LoginType loginType;
}

class AuthLocalSessionStore {
  static const _kUserId = 'auth.session.user_id';
  static const _kLoginType = 'auth.session.login_type';

  Future<void> save({
    required String userId,
    required LoginType loginType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kLoginType, loginType.name);
  }

  Future<LocalAuthSessionSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId)?.trim() ?? '';
    final rawType = prefs.getString(_kLoginType)?.trim() ?? '';
    if (userId.isEmpty || rawType.isEmpty) return null;
    LoginType? loginType;
    for (final item in LoginType.values) {
      if (item.name == rawType) {
        loginType = item;
        break;
      }
    }
    if (loginType == null) return null;
    return LocalAuthSessionSnapshot(userId: userId, loginType: loginType);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kLoginType);
  }
}

final authLocalSessionStoreProvider = Provider<AuthLocalSessionStore>(
  (_) => AuthLocalSessionStore(),
);
