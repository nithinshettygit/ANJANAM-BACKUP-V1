import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Storefront support contact block (email, phone, hours) with [url_launcher] actions.
///
/// Used from [ProfilePage] and reusable anywhere a compact support card is needed.
class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  static final Uri _mailto = Uri.parse('mailto:support.anjanam@gmail.com');
  static final Uri _tel = Uri.parse('tel:+918129107108');

  static const String _emailDisplay = 'support.anjanam@gmail.com';
  static const String _phoneDisplay = '+91 8129107108';
  static const String _availability = 'Mon–Sat, 9 AM – 10 PM';

  Future<void> _launchUri(
    BuildContext context,
    Uri uri, {
    required String failureMessage,
  }) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  void _openContactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Contact support',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.phone_outlined, color: Theme.of(sheetContext).colorScheme.primary),
                title: const Text('Call'),
                subtitle: const Text(_phoneDisplay),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchUri(
                    context,
                    _tel,
                    failureMessage: 'Unable to open dialer',
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.email_outlined, color: Theme.of(sheetContext).colorScheme.primary),
                title: const Text('Email'),
                subtitle: const Text(_emailDisplay),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchUri(
                    context,
                    _mailto,
                    failureMessage: 'Unable to open email app',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Need Help?',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _SupportContactRow(
              icon: Icons.email_outlined,
              title: 'Email',
              value: _emailDisplay,
              iconColor: scheme.primary,
              onTap: () => _launchUri(
                context,
                _mailto,
                failureMessage: 'Unable to open email app',
              ),
            ),
            const SizedBox(height: 10),
            _SupportContactRow(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: _phoneDisplay,
              iconColor: scheme.primary,
              onTap: () => _launchUri(
                context,
                _tel,
                failureMessage: 'Unable to open dialer',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Availability',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _availability,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openContactSheet(context),
              icon: const Icon(Icons.support_agent_outlined, size: 20),
              label: const Text('Contact support'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportContactRow extends StatelessWidget {
  const _SupportContactRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: scheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
