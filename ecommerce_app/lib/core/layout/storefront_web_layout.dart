import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive breakpoints for **web** storefront layouts.
/// Non-web code paths should not branch on these alone—gate with [kIsWeb].
abstract final class StorefrontBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double maxContentWidth = 1320;

  /// Product detail / cart split layout.
  static const double twoColumnDetail = 1024;

  /// Cart summary beside list.
  static const double cartTwoColumn = 900;

  /// Web storefront: show leading sidebar and hide bottom [NavigationBar].
  static const double webNavigationRail = 1024;

  /// Collapsible web sidebar: icons-only rail.
  static const double webStorefrontSidebarWidthCollapsed = 64;

  /// Collapsible web sidebar: icons + labels.
  static const double webStorefrontSidebarWidthExpanded = 160;

  /// Below this viewport width the sidebar stays collapsed (icons only) regardless of user toggle.
  static const double webStorefrontSidebarAutoCollapseBelow = 1200;

  /// Inset between sidebar divider and main storefront panel (web).
  static const double webMainContentPaddingLeft = 20;

  /// Right inset for main storefront panel (web).
  static const double webMainContentPaddingRight = 20;

  /// Wider web layout: use extended [NavigationRail] (icon + label in a row).
  static const double webNavigationRailExtended = 1320;
}

enum StorefrontLayoutClass { mobile, tablet, desktop }

StorefrontLayoutClass storefrontLayoutClassForWidth(double width) {
  if (width < StorefrontBreakpoints.mobile) {
    return StorefrontLayoutClass.mobile;
  }
  if (width < StorefrontBreakpoints.tablet) {
    return StorefrontLayoutClass.tablet;
  }
  return StorefrontLayoutClass.desktop;
}

/// Catalog / search / wishlist grid columns. Android & mobile behavior preserved when !kIsWeb.
int catalogGridCrossAxisCount(double width) {
  if (!kIsWeb) {
    if (width >= 900) return 4;
    if (width >= 650) return 3;
    return 2;
  }
  if (width < StorefrontBreakpoints.mobile) return 2;
  if (width < StorefrontBreakpoints.tablet) return 3;
  if (width >= 1400) return 6;
  if (width >= 1200) return 5;
  return 4;
}

double catalogGridChildAspectRatio(double width) {
  if (!kIsWeb) return 0.44;
  if (width < StorefrontBreakpoints.mobile) return 0.44;
  if (width < StorefrontBreakpoints.tablet) return 0.47;
  return 0.52;
}

double catalogGridSpacing(double width) {
  if (!kIsWeb) return 10;
  return width >= StorefrontBreakpoints.tablet ? 16 : 12;
}

/// Horizontal padding for catalog-style slivers on web desktop.
double catalogHorizontalPadding(BuildContext context) {
  if (!kIsWeb) return 12;
  final w = StorefrontLayoutScope.layoutWidthOf(context);
  if (w >= StorefrontBreakpoints.tablet) return 24;
  if (w >= StorefrontBreakpoints.mobile) return 18;
  return 14;
}

/// Provides the effective storefront content width (capped on web) for responsive metrics.
class StorefrontLayoutScope extends InheritedWidget {
  const StorefrontLayoutScope({
    super.key,
    required this.layoutWidth,
    required super.child,
  });

  final double layoutWidth;

  static double layoutWidthOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StorefrontLayoutScope>();
    if (scope != null) return scope.layoutWidth;
    return MediaQuery.sizeOf(context).width;
  }

  @override
  bool updateShouldNotify(StorefrontLayoutScope oldWidget) {
    return oldWidget.layoutWidth != layoutWidth;
  }
}

/// Main area beside the web sidebar: **viewport-centered** capped column so collapsing
/// the rail does not shift content sideways (avoids left-aligned jump when rail width changes).
///
/// **Flutter Web** only; callers should use inside `Expanded` after [StorefrontWebSidebar].
class WebMainContentPanel extends StatelessWidget {
  const WebMainContentPanel({
    super.key,
    this.maxWidth = StorefrontBreakpoints.maxContentWidth,
    this.padding = const EdgeInsets.fromLTRB(
      StorefrontBreakpoints.webMainContentPaddingLeft,
      0,
      StorefrontBreakpoints.webMainContentPaddingRight,
      0,
    ),
    required this.child,
  });

  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final pad = padding.resolve(Directionality.of(context));
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final innerMax = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final viewportW = MediaQuery.sizeOf(context).width;
          final expandedW = innerMax + pad.left + pad.right;
          final sidebarW = (viewportW - expandedW)
              .clamp(0.0, viewportW)
              .toDouble();
          final w = math.min(innerMax, maxWidth);
          final idealLead =
              (viewportW - w) / 2 - sidebarW - pad.left;
          final lead = idealLead
              .clamp(0.0, math.max(0.0, innerMax - w))
              .toDouble();
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: lead),
              child: SizedBox(
                width: w,
                child: StorefrontLayoutScope(
                  layoutWidth: w,
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Centers storefront content and caps width on **Flutter Web** only.
class WebMaxWidthCenter extends StatelessWidget {
  const WebMaxWidthCenter({
    super.key,
    this.maxWidth = StorefrontBreakpoints.maxContentWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final w = math.min(available, maxWidth);
        return Center(
          child: SizedBox(
            width: w,
            child: StorefrontLayoutScope(
              layoutWidth: w,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Slightly scales key text styles on web desktop for readability. Mobile / Android unchanged.
class StorefrontWebTypography {
  const StorefrontWebTypography._();

  static Widget wrapIfDesktop(BuildContext context, Widget child) {
    if (!kIsWeb) return child;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w <= StorefrontBreakpoints.tablet) return child;

    final theme = Theme.of(context);
    final base = theme.textTheme;

    TextStyle? bump(TextStyle? s, double factor) {
      if (s == null) return null;
      final fs = s.fontSize;
      if (fs == null) return s;
      return s.copyWith(fontSize: fs * factor);
    }

    return Theme(
      data: theme.copyWith(
        textTheme: base.copyWith(
          headlineLarge: bump(base.headlineLarge, 1.05),
          headlineMedium: bump(base.headlineMedium, 1.05),
          headlineSmall: bump(base.headlineSmall, 1.08),
          titleLarge: bump(base.titleLarge, 1.06),
          titleMedium: bump(base.titleMedium, 1.05),
          titleSmall: bump(base.titleSmall, 1.04),
          bodyLarge: bump(base.bodyLarge, 1.045),
          bodyMedium: bump(base.bodyMedium, 1.03),
          labelLarge: bump(base.labelLarge, 1.03),
        ),
      ),
      child: child,
    );
  }
}
