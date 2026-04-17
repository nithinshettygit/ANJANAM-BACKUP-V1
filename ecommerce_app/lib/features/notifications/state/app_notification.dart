import 'package:flutter/foundation.dart';

/// In-app notification record shown to the user.
///
/// This maps to your Supabase `public.user_notifications` table.
@immutable
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String kind;
  final String? redirectType;
  final String? redirectValue;
  final String? orderId;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    required this.createdAt,
    required this.readAt,
    this.redirectType,
    this.redirectValue,
    this.orderId,
    this.imageUrl,
  });

  bool get isRead => readAt != null;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? kind,
    String? redirectType,
    String? redirectValue,
    String? orderId,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      kind: kind ?? this.kind,
      redirectType: redirectType ?? this.redirectType,
      redirectValue: redirectValue ?? this.redirectValue,
      orderId: orderId ?? this.orderId,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

