import 'package:ecommerce_app/core/auth/blocked_account_codes.dart';
import 'package:ecommerce_app/core/auth/blocked_account_gate.dart';
import 'package:ecommerce_app/core/branding/app_brand_assets.dart' show kAppBrandLogoAsset;
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/widgets/support_section.dart';
import 'package:flutter/material.dart';

/// Full-screen UX when a user or admin account is blocked.
class AccountRestrictedPage extends StatelessWidget {
  const AccountRestrictedPage({
    super.key,
    this.message,
    this.blockedReason,
    this.errorCode,
  });

  final String? message;
  final String? blockedReason;
  final String? errorCode;

  String get _bodyMessage {
    final reason = blockedReason?.trim();
    if (reason != null && reason.isNotEmpty) {
      return '${BlockedAccountCopy.screenMessage}\n\nReason: $reason';
    }
    final custom = message?.trim();
    if (custom != null &&
        custom.isNotEmpty &&
        custom != BlockedAccountCopy.screenMessage) {
      return custom;
    }
    return BlockedAccountCopy.screenMessage;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        kAppBrandLogoAsset,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Icon(
                      Icons.block_outlined,
                      size: 48,
                      color: scheme.error.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      BlockedAccountCopy.screenTitle,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.priceText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _bodyMessage,
                      style: textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (errorCode != null && errorCode!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reference: ${errorCode!.trim()}',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    const SupportSection(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          BlockedAccountGate.instance?.markRestrictedRouteClosed();
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (_) => false,
                          );
                        },
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
