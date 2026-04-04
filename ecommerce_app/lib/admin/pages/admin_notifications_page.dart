import 'package:flutter/foundation.dart';
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
    this.manualHint,
  });

  final String id;
  final String label;
  final String apiRedirectType;
  final bool needsManualValue;
  final String manualLabel;
  final String? manualHint;
}

/// Presets must match [NotificationTapNavigator] + Edge `redirect_type` strings.
const List<_RedirectPreset> _kRedirectPresets = [
  _RedirectPreset(
    id: 'none',
    label: 'Notification only — full screen (no store link)',
    apiRedirectType: 'none',
  ),
  _RedirectPreset(
    id: 'home_popular',
    label: 'Store · Popular products (home section)',
    apiRedirectType: 'home_popular',
  ),
  _RedirectPreset(
    id: 'home_recommended',
    label: 'Store · Recommended for you',
    apiRedirectType: 'home_recommended',
  ),
  _RedirectPreset(
    id: 'home_festival',
    label: 'Store · Festival specials',
    apiRedirectType: 'home_festival',
  ),
  _RedirectPreset(
    id: 'home_new_arrivals',
    label: 'Store · New arrivals',
    apiRedirectType: 'home_new_arrivals',
  ),
  _RedirectPreset(
    id: 'catalog_browse',
    label: 'Store · Full product catalog',
    apiRedirectType: 'catalog_browse',
  ),
  _RedirectPreset(
    id: 'screen_books',
    label: 'Books',
    apiRedirectType: 'screen_books',
  ),
  _RedirectPreset(
    id: 'screen_videos',
    label: 'Videos',
    apiRedirectType: 'screen_videos',
  ),
  _RedirectPreset(
    id: 'screen_music',
    label: 'Music',
    apiRedirectType: 'screen_music',
  ),
  _RedirectPreset(
    id: 'screen_wishlist',
    label: 'Wishlist',
    apiRedirectType: 'screen_wishlist',
  ),
  _RedirectPreset(
    id: 'screen_cart',
    label: 'Shopping cart',
    apiRedirectType: 'screen_cart',
  ),
  _RedirectPreset(
    id: 'screen_orders',
    label: 'My orders',
    apiRedirectType: 'screen_orders',
  ),
  _RedirectPreset(
    id: 'screen_search',
    label: 'Search',
    apiRedirectType: 'screen_search',
  ),
  _RedirectPreset(
    id: 'screen_profile',
    label: 'Profile',
    apiRedirectType: 'screen_profile',
  ),
  _RedirectPreset(
    id: 'screen_more',
    label: 'More menu',
    apiRedirectType: 'screen_more',
  ),
  _RedirectPreset(
    id: 'product',
    label: 'Product — manual product ID',
    apiRedirectType: 'product',
    needsManualValue: true,
    manualLabel: 'Product ID',
    manualHint: 'UUID from products table',
  ),
  _RedirectPreset(
    id: 'category',
    label: 'Category — manual slug',
    apiRedirectType: 'category',
    needsManualValue: true,
    manualLabel: 'Category slug',
    manualHint: 'e.g. tea, books',
  ),
  _RedirectPreset(
    id: 'order',
    label: 'Order — manual order ID',
    apiRedirectType: 'order',
    needsManualValue: true,
    manualLabel: 'Order ID',
    manualHint: 'Customer order UUID',
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
  final _redirectManualCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();

  String _notificationKind = 'promotion';
  String _redirectPresetId = 'none';
  bool _broadcastAll = true;
  bool _busy = false;

  _RedirectPreset get _selectedPreset {
    return _kRedirectPresets.firstWhere(
      (p) => p.id == _redirectPresetId,
      orElse: () => _kRedirectPresets.first,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _redirectManualCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final preset = _selectedPreset;
    final manual = _redirectManualCtrl.text.trim();

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }
    if (message.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is required')),
      );
      return;
    }
    if (!_broadcastAll && _userIdCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID is required for targeted notifications'),
        ),
      );
      return;
    }

    if (preset.needsManualValue && manual.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter ${preset.manualLabel.toLowerCase()} for this redirect.'),
        ),
      );
      return;
    }

    final redirectType = preset.apiRedirectType;
    final redirectValue = preset.needsManualValue ? manual : '';

    setState(() => _busy = true);
    try {
      final result = await ref.read(fcmNotificationSenderProvider).sendUserNotification(
            title: title,
            message: message,
            kind: _notificationKind,
            redirectType: redirectType,
            redirectValue: redirectValue,
            broadcast: _broadcastAll,
            userId: _broadcastAll ? null : _userIdCtrl.text.trim(),
          );

      if (!mounted) return;
      final String snackText;
      if (result.attempted == 0) {
        final note = result.note?.trim();
        final clientSkip = note != null &&
            (note.toLowerCase().contains('edge function url') ||
                note.toLowerCase().contains('functions_base_url'));
        if (clientSkip) {
          snackText = note;
        } else if (note != null && note.isNotEmpty) {
          snackText = 'In-app notification saved. Push not sent: $note';
        } else {
          var s = 'In-app notification saved. No push: no FCM tokens in user_devices. '
              'Logins alone do not register tokens—users need the Android app open '
              'with notifications allowed (web does not register push).';
          if (kIsWeb) {
            s = '$s Chrome admin never receives FCM—check an Android device.';
          }
          snackText = s;
        }
      } else {
        var line = 'Push sent: ${result.success}/${result.attempted} success'
            '${result.failure > 0 ? ', ${result.failure} failed' : ''}';
        final extra = result.note?.trim();
        if (extra != null && extra.isNotEmpty) line = '$line. $extra';
        if (kIsWeb) {
          line =
              '$line — FCM delivers to the Android app on a device, not this browser.';
        }
        snackText = line;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(snackText),
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
    final preset = _selectedPreset;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Send Notifications',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                    value: _notificationKind,
                    decoration: const InputDecoration(
                      labelText: 'Notification type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
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
                    'Open in app when customer taps',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a home section, screen, or enter an ID for product / category / order.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _redirectPresetId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    items: _kRedirectPresets
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _redirectPresetId = v ?? 'none';
                      if (!_selectedPreset.needsManualValue) {
                        _redirectManualCtrl.clear();
                      }
                    }),
                  ),
                  if (preset.needsManualValue) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _redirectManualCtrl,
                      decoration: InputDecoration(
                        labelText: preset.manualLabel,
                        hintText: preset.manualHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (!preset.needsManualValue && preset.apiRedirectType == 'none')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Customer sees this message full screen with a back button — '
                        'no automatic jump to products or orders.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
              label: Text(_busy ? 'Sending…' : 'Send notification'),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
