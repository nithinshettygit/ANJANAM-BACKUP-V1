import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_env.dart';

/// Loads [AppEnv] from `https://<current-origin>/app-config.json` when web was built
/// without `--dart-define=SUPABASE_*` (same-origin fetch; anon key is public client config).
Future<AppEnv?> tryLoadWebHostedAppConfig() async {
  if (!kIsWeb) return null;
  final origin = Uri.base.origin;
  if (origin.isEmpty) return null;
  final uri = Uri.parse(origin).replace(path: '/app-config.json');
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200 || r.body.trim().isEmpty) return null;
    final decoded = jsonDecode(r.body);
    if (decoded is! Map<String, dynamic>) return null;
    return AppEnv.fromHostedConfigJson(decoded);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('app-config.json: $e');
      debugPrint('$st');
    }
    return null;
  }
}
