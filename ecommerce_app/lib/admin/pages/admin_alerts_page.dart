import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_notification.dart';
import '../providers/admin_notification_providers.dart';

class AdminAlertsPage extends ConsumerStatefulWidget {
  const AdminAlertsPage({super.key});

  @override
  ConsumerState<AdminAlertsPage> createState() => _AdminAlertsPageState();
}

class _AdminAlertsPageState extends ConsumerState<AdminAlertsPage> {
  bool _loading = true;
  String? _error;
  int _unreadCount = 0;
  List<AdminNotificationRow> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final service = ref.read(adminNotificationServiceProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await service.fetchNotifications();
      final unread = data.where((n) => !n.isRead).length;
      if (!mounted) return;
      setState(() {
        _items = data;
        _unreadCount = unread;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(adminNotificationServiceProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Alerts',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  if (_unreadCount > 0)
                    FilledButton.icon(
                      onPressed: () async {
                        await service.markAllAsRead();
                        await _refresh();
                      },
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text('Mark all read ($_unreadCount)'),
                    ),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              const Text(
                'Admin Alerts',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              if (_unreadCount > 0)
                FilledButton.icon(
                  onPressed: () async {
                    await service.markAllAsRead();
                    await _refresh();
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  label: Text('Mark all read ($_unreadCount)'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody(service)),
      ],
    );
  }

  Widget _buildBody(service) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Failed to load notifications: $_error'));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No admin notifications yet.'));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: ListTile(
            leading: _PriorityDot(priority: item.priority),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${item.message}\n${_timeLabel(item.createdAt)}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: item.isRead
                ? null
                : const Icon(Icons.brightness_1, size: 10, color: Colors.red),
            isThreeLine: true,
            onTap: () async {
              if (!item.isRead) {
                await service.markAsRead(item.id);
                await _refresh();
              }
              if (!context.mounted) return;
              _openNotificationTarget(context, item);
            },
          ),
        );
      },
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => Colors.red,
      'medium' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return CircleAvatar(
      radius: 10,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(Icons.notifications_active_rounded, size: 12, color: color),
    );
  }
}

String _timeLabel(DateTime dtUtc) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(dtUtc);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

void _openNotificationTarget(BuildContext context, AdminNotificationRow item) {
  final referenceId = item.referenceId;
  switch (item.type) {
    case 'order_created':
      if (referenceId != null && referenceId.isNotEmpty) {
        Navigator.of(context).pushNamed('/admin/orders/details/$referenceId');
      } else {
        Navigator.of(context).pushNamed('/admin/orders');
      }
      return;
    case 'new_user':
      if (referenceId != null && referenceId.isNotEmpty) {
        Navigator.of(context).pushNamed('/admin/users/details/$referenceId');
      } else {
        Navigator.of(context).pushNamed('/admin/users');
      }
      return;
    case 'product_review':
      Navigator.of(context).pushReplacementNamed('/admin/product-reviews');
      return;
    case 'product_question':
      Navigator.of(context).pushReplacementNamed('/admin/product-questions');
      return;
    case 'return_request':
    case 'refund_request':
      Navigator.of(context).pushReplacementNamed('/admin/returns');
      return;
    case 'low_stock':
    case 'out_of_stock':
      Navigator.of(context).pushReplacementNamed('/admin/inventory');
      return;
    default:
      Navigator.of(context).pushReplacementNamed('/admin/admin-notifications');
      return;
  }
}

