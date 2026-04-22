import 'package:flutter/foundation.dart';

/// Public pages for Play Store compliance (Privacy, Terms, Refund, Support, Delete Account).
///
/// Override hosting base: `--dart-define=STOREFRONT_LEGAL_BASE_URL=https://anjanam.app`
/// On web, defaults to [Uri.base.origin] when no define is set (same deployment).
enum StorefrontLegalPage {
  privacyPolicy,
  terms,
  refundPolicy,
  support,
  deleteAccount,
}

String storefrontLegalBaseUrl() {
  const fromEnv = String.fromEnvironment(
    'STOREFRONT_LEGAL_BASE_URL',
    defaultValue: '',
  );
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
  if (kIsWeb) {
    final o = Uri.base.origin;
    if (o.isNotEmpty) return o.replaceAll(RegExp(r'/+$'), '');
  }
  return 'https://anjanam-app.web.app';
}

String storefrontLegalPath(StorefrontLegalPage page) {
  return switch (page) {
    StorefrontLegalPage.privacyPolicy => '/privacy-policy',
    StorefrontLegalPage.terms => '/terms',
    StorefrontLegalPage.refundPolicy => '/refund-policy',
    StorefrontLegalPage.support => '/support',
    StorefrontLegalPage.deleteAccount => '/delete-account',
  };
}

String storefrontLegalPageUrl(StorefrontLegalPage page) {
  return '${storefrontLegalBaseUrl()}${storefrontLegalPath(page)}';
}

/// Shown in policy text (mailto). Replace with your production inbox if different.
const String storefrontSupportEmail = 'support@anjanam.store';
