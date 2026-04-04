import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/home_content/domain/home_top_category_item.dart';
import 'app_network_image.dart';
import 'home_layout_metrics.dart';
import 'web_horizontal_rail_list.dart';

/// Flipkart-style circular category chips in a horizontal scroller.
class HomeTopCategoriesRow extends StatelessWidget {
  const HomeTopCategoriesRow({
    super.key,
    required this.items,
    this.circleSize = 56,
  });

  final List<HomeTopCategoryItem> items;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Quick picks',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.brandSaffronDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: HomeLayoutMetrics.homeSectionBadgeFontSize(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Shop by category',
                style: HomeLayoutMetrics.homeCategoryRowTitleStyle(context, theme.textTheme) ??
                    theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(height: HomeLayoutMetrics.homeCategoryHeaderToScrollerGap(context)),
        WebHorizontalRailList(
          height: circleSize + 48,
          padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              SizedBox(width: HomeLayoutMetrics.homeCategoryScrollerGap(context)),
          itemBuilder: (context, index) {
            final c = items[index];
            final slug = c.categorySlug.trim().toLowerCase();
            return _CategoryChip(
              label: c.label,
              iconUrl: c.iconUrl,
              circleSize: circleSize,
              onTap: slug.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pushNamed(
                        '/products',
                        arguments: {
                          'category': slug,
                          'title': c.label,
                        },
                      );
                    },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.iconUrl,
    required this.circleSize,
    this.onTap,
  });

  final String label;
  final String iconUrl;
  final double circleSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: circleSize + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circleSize + 4,
                  height: circleSize + 4,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceCard,
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconUrl.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.category_outlined,
                              size: circleSize * 0.42,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : AppNetworkImage(
                            imageUrl: iconUrl,
                            width: circleSize,
                            height: circleSize,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(circleSize / 2),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
