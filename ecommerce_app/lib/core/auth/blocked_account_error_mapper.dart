import 'dart:convert';

import 'package:ecommerce_app/core/auth/blocked_account_codes.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:gotrue/gotrue.dart' as gt;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

enum BlockedAccountKind { user, admin }

class BlockedAccountDetection {
  final BlockedAccountKind kind;
  final String errorCode;
  final String userMessage;
  final String? blockedReason;

  const BlockedAccountDetection({
    required this.kind,
    required this.errorCode,
    required this.userMessage,
    this.blockedReason,
  });

  AuthException toAuthException() => AuthException(
        userMessage,
        kind: AuthFailureKind.accountSuspended,
      );

  BlockedAccountDetection copyWith({String? userMessage}) {
    return BlockedAccountDetection(
      kind: kind,
      errorCode: errorCode,
      userMessage: userMessage ?? this.userMessage,
      blockedReason: blockedReason,
    );
  }
}

/// Maps backend / Supabase errors to a stable blocked-account signal.
abstract final class BlockedAccountErrorMapper {
  static BlockedAccountDetection? tryParse(Object error) {
    if (error is AuthException && error.kind == AuthFailureKind.accountSuspended) {
      return BlockedAccountDetection(
        kind: BlockedAccountKind.user,
        errorCode: BlockedAccountCodes.userBlocked,
        userMessage: _friendlyMessage(error.message),
        blockedReason: _extractReason(error.message),
      );
    }

    if (error is PostgrestException) {
      return _fromPostgrest(error);
    }

    if (error is FunctionException) {
      return _fromFunctionException(error);
    }

    if (error is gt.AuthException) {
      return _fromGotrue(error);
    }

    if (error is RepositoryException) {
      return _fromPlain(error.message);
    }

    return _fromPlain(error.toString());
  }

  static BlockedAccountDetection? fromRestrictionRpc(Map<String, dynamic> json) {
    final restricted = json['restricted'] == true ||
        json['restricted']?.toString().toLowerCase() == 'true';
    if (!restricted) return null;

    final code = json['error_code']?.toString().trim();
    final reason = json['blocked_reason']?.toString().trim();
    final serverMessage = json['message']?.toString().trim();

    final kind = BlockedAccountCodes.matches(code) &&
            code!.toUpperCase() == BlockedAccountCodes.adminBlocked
        ? BlockedAccountKind.admin
        : BlockedAccountKind.user;

    final errorCode = (code != null && code.isNotEmpty)
        ? code.toUpperCase()
        : (kind == BlockedAccountKind.admin
            ? BlockedAccountCodes.adminBlocked
            : BlockedAccountCodes.userBlocked);

    return BlockedAccountDetection(
      kind: kind,
      errorCode: errorCode,
      userMessage: _friendlyMessage(serverMessage, reason: reason),
      blockedReason: reason?.isEmpty == true ? null : reason,
    );
  }

  static bool looksLikeAccessPolicyDenial(Object error) {
    if (error is! PostgrestException) return false;
    final blob =
        '${error.message} ${error.code ?? ''} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return blob.contains('row-level security') ||
        blob.contains('row level security') ||
        blob.contains('violates row-level security') ||
        blob.contains('permission denied') ||
        error.code == '42501' ||
        error.code == 'PGRST301';
  }

  static BlockedAccountDetection? _fromPostgrest(PostgrestException e) {
    final parsed = _fromStructuredPayload(e.details) ??
        _fromStructuredPayload(e.message) ??
        _fromPlain('${e.message} ${e.code ?? ''} ${e.details ?? ''}');
    if (parsed != null) return parsed;

    if (looksLikeAccessPolicyDenial(e)) {
      return const BlockedAccountDetection(
        kind: BlockedAccountKind.user,
        errorCode: BlockedAccountCodes.userBlocked,
        userMessage: BlockedAccountCopy.screenMessage,
      );
    }
    return null;
  }

  static BlockedAccountDetection? _fromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      return fromRestrictionRpc(Map<String, dynamic>.from(details)) ??
          _fromStructuredPayload(details);
    }
    if (details is String) {
      return _fromStructuredPayload(details) ?? _fromPlain(details);
    }
    return _fromPlain(e.reasonPhrase ?? e.toString());
  }

  static BlockedAccountDetection? _fromGotrue(gt.AuthException e) {
    final code = e.code ?? '';
    if (BlockedAccountCodes.matches(code) ||
        e.message.toLowerCase().contains('blocked') ||
        e.message.toLowerCase().contains('suspended') ||
        e.message.toLowerCase().contains('disabled')) {
      final kind = code.toUpperCase() == BlockedAccountCodes.adminBlocked
          ? BlockedAccountKind.admin
          : BlockedAccountKind.user;
      return BlockedAccountDetection(
        kind: kind,
        errorCode: code.isEmpty ? BlockedAccountCodes.userBlocked : code.toUpperCase(),
        userMessage: _friendlyMessage(e.message),
      );
    }
    return null;
  }

  static BlockedAccountDetection? _fromStructuredPayload(Object? raw) {
    if (raw == null) return null;
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) map = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    if (map == null) return null;

    final code = map['error_code']?.toString() ?? map['code']?.toString();
    if (!BlockedAccountCodes.matches(code)) {
      final msg = map['message']?.toString() ?? '';
      if (!_plainLooksBlocked(msg)) return null;
    }

    final kind = BlockedAccountCodes.matches(code) &&
            code!.toUpperCase() == BlockedAccountCodes.adminBlocked
        ? BlockedAccountKind.admin
        : BlockedAccountKind.user;

    final reason = map['blocked_reason']?.toString();
    final message = map['message']?.toString();

    return BlockedAccountDetection(
      kind: kind,
      errorCode: (code != null && code.isNotEmpty)
          ? code.toUpperCase()
          : BlockedAccountCodes.userBlocked,
      userMessage: _friendlyMessage(message, reason: reason),
      blockedReason: reason?.trim().isEmpty == true ? null : reason?.trim(),
    );
  }

  static BlockedAccountDetection? _fromPlain(String raw) {
    final lower = raw.toLowerCase();
    if (!_plainLooksBlocked(lower)) return null;

    final kind = lower.contains('admin') && lower.contains('block')
        ? BlockedAccountKind.admin
        : BlockedAccountKind.user;

    return BlockedAccountDetection(
      kind: kind,
      errorCode: kind == BlockedAccountKind.admin
          ? BlockedAccountCodes.adminBlocked
          : BlockedAccountCodes.userBlocked,
      userMessage: _friendlyMessage(raw),
    );
  }

  static bool _plainLooksBlocked(String lower) {
    return lower.contains('user_blocked') ||
        lower.contains('admin_blocked') ||
        lower.contains('account_disabled') ||
        lower.contains('account_blocked') ||
        lower.contains('account is blocked') ||
        lower.contains('account has been suspended') ||
        lower.contains('account has been blocked') ||
        lower.contains('temporarily blocked') ||
        (lower.contains('blocked') && lower.contains('admin'));
  }

  static String _friendlyMessage(String? serverMessage, {String? reason}) {
    final cleanReason = reason?.trim();
    if (cleanReason != null && cleanReason.isNotEmpty) {
      return '${BlockedAccountCopy.screenMessage}\n\nReason: $cleanReason';
    }
    final msg = serverMessage?.trim() ?? '';
    if (msg.isEmpty || msg.length > 220 || _looksTechnical(msg)) {
      return BlockedAccountCopy.screenMessage;
    }
    if (msg == BlockedAccountCopy.screenMessage) return msg;
    if (_plainLooksBlocked(msg.toLowerCase())) {
      return BlockedAccountCopy.screenMessage;
    }
    return BlockedAccountCopy.screenMessage;
  }

  static bool _looksTechnical(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('postgrest') ||
        lower.contains('exception') ||
        lower.contains('stack') ||
        lower.contains('sql') ||
        lower.contains('pgrst') ||
        lower.contains('violates') ||
        lower.contains('policy');
  }

  static String? _extractReason(String message) {
    const prefix = 'Reason:';
    final idx = message.indexOf(prefix);
    if (idx < 0) return null;
    final reason = message.substring(idx + prefix.length).trim();
    return reason.isEmpty ? null : reason;
  }
}
