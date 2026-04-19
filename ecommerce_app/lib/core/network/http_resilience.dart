import 'dart:async';

import 'package:http/http.dart' as http;

class HttpResilience {
  HttpResilience._();

  static const Duration defaultTimeout = Duration(seconds: 12);

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
    int retries = 1,
  }) async {
    return _withRetry(
      () => http.get(uri, headers: headers).timeout(timeout),
      retries: retries,
    );
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = defaultTimeout,
    int retries = 1,
  }) async {
    return _withRetry(
      () => http.post(uri, headers: headers, body: body).timeout(timeout),
      retries: retries,
    );
  }

  static Future<http.Response> _withRetry(
    Future<http.Response> Function() operation, {
    required int retries,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await operation();
      } on TimeoutException {
        if (attempt > retries) rethrow;
      } on http.ClientException {
        if (attempt > retries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
}

