import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../auth/blocked_account_gate.dart';
import '../errors/app_exception.dart';

class NetworkRequestGuard {
  NetworkRequestGuard._();

  static const Duration defaultTimeout = Duration(seconds: 12);
  static const int defaultRetries = 2;

  static const String offlineMessage =
      "You're offline. Please connect to the internet.";
  static const String noInternetMessage =
      'No internet connection. Please check your network and try again.';
  static const String timeoutMessage = 'Request timed out. Please try again.';

  static Future<bool> hasConnection() async {
    try {
      final current = await Connectivity().checkConnectivity();
      return current.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // If connectivity probing fails, do not block attempts.
      return true;
    }
  }

  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration timeout = defaultTimeout,
    int retries = defaultRetries,
    bool checkConnectivityFirst = true,
    String operation = 'network request',
  }) async {
    if (checkConnectivityFirst && !await hasConnection()) {
      throw const NetworkException(offlineMessage);
    }

    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await action().timeout(timeout);
      } on TimeoutException catch (e, st) {
        _debugLog(operation, e, st, attempt);
        if (attempt > retries) {
          throw const NetworkException(timeoutMessage);
        }
      } catch (e, st) {
        if (!_isTransientNetworkError(e)) {
          await BlockedAccountGate.rethrowIfHandled(e);
          rethrow;
        }
        _debugLog(operation, e, st, attempt);
        if (attempt > retries) {
          throw const NetworkException(noInternetMessage);
        }
      }

      final seconds = 1 << (attempt - 1); // 1s -> 2s
      await Future<void>.delayed(Duration(seconds: seconds));
    }
  }

  static bool isTransientNetworkError(Object error) => _isTransientNetworkError(error);

  static bool _isTransientNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('socket exception') ||
        text.contains('network is unreachable') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network-request-failed') ||
        text.contains('authretryablefetchexception') ||
        text.contains('clientexception');
  }

  static void _debugLog(
    String operation,
    Object error,
    StackTrace stackTrace,
    int attempt,
  ) {
    if (!kDebugMode) return;
    debugPrint('[NetworkGuard] $operation attempt=$attempt failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

