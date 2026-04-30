import 'package:flutter/material.dart';

/// Small, reusable full-page error screen used for deep-link validation.
class ErrorScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? primaryButtonLabel;
  final VoidCallback? onPrimaryButton;

  const ErrorScreen({
    super.key,
    this.icon = Icons.wifi_off_outlined,
    required this.title,
    required this.message,
    this.primaryButtonLabel,
    this.onPrimaryButton,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (primaryButtonLabel != null && onPrimaryButton != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: onPrimaryButton,
                  child: Text(primaryButtonLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

