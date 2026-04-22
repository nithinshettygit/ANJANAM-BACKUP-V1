import 'package:flutter/material.dart';

import '../../core/config/storefront_legal_urls.dart';
import '../utils/open_storefront_legal_page.dart';

/// Full card for Account / settings-style screens.
class LegalSupportLinksCard extends StatelessWidget {
  const LegalSupportLinksCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we collect and use data'),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.privacyPolicy),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms & Conditions'),
            subtitle: const Text('Using ANJANAM services'),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.terms),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.currency_exchange_outlined),
            title: const Text('Refund Policy'),
            subtitle: const Text('Returns and refunds'),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.refundPolicy),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Support'),
            subtitle: Text(storefrontSupportEmail),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.support),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_remove_alt_1_outlined),
            title: const Text('Delete Account'),
            subtitle: const Text('How to request account deletion'),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.deleteAccount),
          ),
        ],
      ),
    );
  }
}

/// Compact footer for Explore and other public tabs (no login required).
class LegalSupportFooterCompact extends StatelessWidget {
  const LegalSupportFooterCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Legal & Support', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _TextLink(
                label: 'Privacy',
                onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.privacyPolicy),
                style: style,
              ),
              _TextLink(
                label: 'Terms',
                onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.terms),
                style: style,
              ),
              _TextLink(
                label: 'Refunds',
                onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.refundPolicy),
                style: style,
              ),
              _TextLink(
                label: 'Support',
                onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.support),
                style: style,
              ),
              _TextLink(
                label: 'Delete Account',
                onTap: () => openStorefrontLegalPage(context, StorefrontLegalPage.deleteAccount),
                style: style,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(label, style: style?.copyWith(decoration: TextDecoration.underline)),
      ),
    );
  }
}
