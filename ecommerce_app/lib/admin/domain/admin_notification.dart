class AdminNotificationRow {
  const AdminNotificationRow({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
    required this.priority,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  final String priority;

  factory AdminNotificationRow.fromJson(Map<String, dynamic> json) {
    return AdminNotificationRow(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      referenceId: json['reference_id']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      priority: json['priority']?.toString() ?? 'low',
    );
  }
}

