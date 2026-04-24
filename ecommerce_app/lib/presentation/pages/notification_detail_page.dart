import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/core/notifications/notification_markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';

/// Full-screen read view for a single notification (no deep link).
class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({
    super.key,
    required this.notificationId,
    required this.title,
    required this.message,
    this.createdAt,
    this.kindLabel,
    this.imageUrl,
  });

  final String notificationId;
  final String title;
  final String message;
  final DateTime? createdAt;
  final String? kindLabel;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formatted = createdAt != null ? _formatLocal(createdAt!) : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surfaceCard,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              'Notification',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (kindLabel != null && kindLabel!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: AppColors.brandSaffron.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              kindLabel!.trim(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.brandSaffronDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: notificationMarkdownSpans(
                        input: title.trim().isEmpty ? 'Update' : title.trim(),
                        baseStyle: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: AppColors.textPrimary,
                        ),
                        boldStyle: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (formatted != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (imageUrl != null && imageUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: AppNetworkImage(
                        imageUrl: imageUrl!.trim(),
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText.rich(
                        TextSpan(
                          children: notificationMarkdownSpans(
                            input: message.trim().isEmpty
                                ? 'No additional details.'
                                : message.trim(),
                            baseStyle: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.55,
                              color: AppColors.textPrimary,
                            ),
                            boldStyle: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.55,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      foregroundColor: AppColors.brandSaffronDeep,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatLocal(DateTime dt) {
    final l = dt.toLocal();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final mon = months[l.month - 1];
    final h = l.hour > 12 ? l.hour - 12 : (l.hour == 0 ? 12 : l.hour);
    final am = l.hour >= 12 ? 'PM' : 'AM';
    final mm = l.minute.toString().padLeft(2, '0');
    return '$mon ${l.day}, ${l.year} · $h:$mm $am';
  }
}
