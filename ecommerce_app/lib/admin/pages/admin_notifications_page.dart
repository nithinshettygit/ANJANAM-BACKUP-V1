import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/data/services/fcm_edge_function_notification_sender.dart';

class _RedirectPreset {
  const _RedirectPreset({
    required this.id,
    required this.label,
    required this.apiRedirectType,
    this.needsManualValue = false,
    this.manualLabel = 'ID or slug',
  });

  final String id;
  final String label;
  final String apiRedirectType;
  final bool needsManualValue;
  final String manualLabel;
}

const List<_RedirectPreset> _kRedirectPresets = [
  _RedirectPreset(id: 'none', label: 'Notification only', apiRedirectType: 'none'),
  _RedirectPreset(id: 'home_popular', label: 'Home · Popular', apiRedirectType: 'home_popular'),
  _RedirectPreset(
    id: 'home_recommended',
    label: 'Home · Recommended',
    apiRedirectType: 'home_recommended',
  ),
  _RedirectPreset(id: 'home_festival', label: 'Home · Festival', apiRedirectType: 'home_festival'),
  _RedirectPreset(
    id: 'home_new_arrivals',
    label: 'Home · New arrivals',
    apiRedirectType: 'home_new_arrivals',
  ),
  _RedirectPreset(id: 'catalog_browse', label: 'Catalog', apiRedirectType: 'catalog_browse'),
  _RedirectPreset(id: 'screen_books', label: 'Books', apiRedirectType: 'screen_books'),
  _RedirectPreset(id: 'screen_videos', label: 'Videos', apiRedirectType: 'screen_videos'),
  _RedirectPreset(id: 'screen_music', label: 'Music', apiRedirectType: 'screen_music'),
  _RedirectPreset(id: 'screen_wishlist', label: 'Wishlist', apiRedirectType: 'screen_wishlist'),
  _RedirectPreset(id: 'screen_cart', label: 'Cart', apiRedirectType: 'screen_cart'),
  _RedirectPreset(id: 'screen_orders', label: 'Orders', apiRedirectType: 'screen_orders'),
  _RedirectPreset(id: 'screen_search', label: 'Search', apiRedirectType: 'screen_search'),
  _RedirectPreset(id: 'screen_profile', label: 'Profile', apiRedirectType: 'screen_profile'),
  _RedirectPreset(id: 'screen_more', label: 'More', apiRedirectType: 'screen_more'),
  _RedirectPreset(
    id: 'product',
    label: 'Product ID',
    apiRedirectType: 'product',
    needsManualValue: true,
    manualLabel: 'Product ID',
  ),
  _RedirectPreset(
    id: 'category',
    label: 'Category slug',
    apiRedirectType: 'category',
    needsManualValue: true,
    manualLabel: 'Category slug',
  ),
  _RedirectPreset(
    id: 'order',
    label: 'Order ID',
    apiRedirectType: 'order',
    needsManualValue: true,
    manualLabel: 'Order ID',
  ),
];

class AdminNotificationsPage extends ConsumerStatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  ConsumerState<AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends ConsumerState<AdminNotificationsPage> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _manualCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();

  String _kind = 'promotion';
  String _presetId = 'none';
  bool _broadcastAll = true;
  bool _busy = false;

  _RedirectPreset get _preset => _kRedirectPresets.firstWhere(
        (e) => e.id == _presetId,
        orElse: () => _kRedirectPresets.first,
      );

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _manualCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) return;
    if (!_broadcastAll && _userIdCtrl.text.trim().isEmpty) return;
    if (_preset.needsManualValue && _manualCtrl.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(fcmNotificationSenderProvider).sendUserNotification(
            title: title,
            message: message,
            kind: _kind,
            redirectType: _preset.apiRedirectType,
            redirectValue: _preset.needsManualValue ? _manualCtrl.text.trim() : '',
            broadcast: _broadcastAll,
            userId: _broadcastAll ? null : _userIdCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.attempted == 0
                ? 'In-app notification saved. Push not sent.'
                : 'Push sent: ${result.success}/${result.attempted}',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Notifications',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Broadcast to all users'),
                value: _broadcastAll,
                onChanged: (v) => setState(() => _broadcastAll = v),
              ),
              if (!_broadcastAll)
                TextField(
                  controller: _userIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target User ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _kind,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
                  DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 'promotion'),
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
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _presetId,
                decoration: const InputDecoration(
                  labelText: 'Redirect destination',
                  border: OutlineInputBorder(),
                ),
                items: _kRedirectPresets
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _presetId = v ?? 'none';
                  if (!_preset.needsManualValue) _manualCtrl.clear();
                }),
              ),
              if (_preset.needsManualValue) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _manualCtrl,
                  decoration: InputDecoration(
                    labelText: _preset.manualLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send_rounded),
                label: Text(_busy ? 'Sending...' : 'Send Notification'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
