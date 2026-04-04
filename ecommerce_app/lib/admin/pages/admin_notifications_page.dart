import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/data/services/fcm_edge_function_notification_sender.dart';

class AdminNotificationsPage extends ConsumerStatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  ConsumerState<AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState
    extends ConsumerState<AdminNotificationsPage> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _redirectTargetCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();

  String _notificationKind = 'promotion'; // promotion | announcement
  String _redirectType = 'None'; // Product | Category | Order | None
  bool _broadcastAll = true;

  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _redirectTargetCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  String _normalizedRedirectType() {
    final v = _redirectType.trim().toLowerCase();
    switch (v) {
      case 'product':
        return 'product';
      case 'category':
        return 'category';
      case 'order':
        return 'order';
      case 'none':
      default:
        return 'none';
    }
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final redirectType = _normalizedRedirectType();
    final redirectValue = _redirectTargetCtrl.text.trim();

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    if (message.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message is required')));
      return;
    }
    if (_broadcastAll == false && _userIdCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID is required for targeted notifications')));
      return;
    }

    // Redirect target is optional for `None`.
    if (redirectType != 'none' && redirectValue.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redirect target is required for Product/Category/Order')));
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(fcmNotificationSenderProvider)
          .sendUserNotification(
            title: title,
            message: message,
            kind: _notificationKind,
            redirectType: redirectType,
            redirectValue: redirectType == 'none' ? '' : redirectValue,
            broadcast: _broadcastAll,
            userId: _broadcastAll ? null : _userIdCtrl.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            result.attempted == 0
                ? (result.note?.isNotEmpty == true
                    ? 'In-app notification saved. Push not sent: ${result.note}'
                    : 'In-app notification saved. No push: no FCM tokens in user_devices. '
                        'Logins alone do not register tokens—users need the Android app open '
                        'with notifications allowed (web does not register push).')
                : 'Push sent: ${result.success}/${result.attempted} success'
                    '${result.failure > 0 ? ', ${result.failure} failed' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              const Text(
                'Send Notifications',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Audience',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Broadcast to all users'),
                    subtitle: const Text(
                      'Creates in-app notifications for users. Push only goes to devices '
                      'that registered an FCM token (Android app, permission granted)—not web logins.',
                    ),
                    value: _broadcastAll,
                    onChanged: (v) => setState(() => _broadcastAll = v),
                  ),
                  if (!_broadcastAll) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _userIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Target User ID',
                        hintText: 'UUID from auth.users.id',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Content',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _notificationKind,
                    decoration: const InputDecoration(
                      labelText: 'Notification Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'promotion',
                        child: Text('Promotion'),
                      ),
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('Announcement'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _notificationKind = v ?? 'promotion'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Redirect',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _redirectType,
                    decoration: const InputDecoration(
                      labelText: 'Redirect Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'None', child: Text('None')),
                      DropdownMenuItem(
                        value: 'Product',
                        child: Text('Product'),
                      ),
                      DropdownMenuItem(
                        value: 'Category',
                        child: Text('Category'),
                      ),
                      DropdownMenuItem(
                        value: 'Order',
                        child: Text('Order'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _redirectType = v ?? 'None'),
                  ),
                  const SizedBox(height: 12),
                  if (_redirectType.toLowerCase() != 'none') ...[
                    TextField(
                      controller: _redirectTargetCtrl,
                      decoration: InputDecoration(
                        labelText: 'Redirect Target',
                        hintText: _redirectType == 'Category'
                            ? 'Category slug (e.g. tea)'
                            : 'UUID / ID depending on redirect type',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_redirectType.toLowerCase() == 'none')
                    Text(
                      'Redirect disabled. Tapping the notification will open the Notifications history.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending…' : 'Send Notification'),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

