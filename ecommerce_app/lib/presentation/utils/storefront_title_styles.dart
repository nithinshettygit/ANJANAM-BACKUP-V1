import 'package:flutter/material.dart';

/// Same family, weight, and color as the app [AppBar] title, with a slightly larger size for key titles.
TextStyle storefrontHeroTitleStyle(BuildContext context) {
  final theme = Theme.of(context);
  final base = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
  if (base == null) {
    return const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    );
  }
  return base.copyWith(fontSize: 20);
}

/// App bar titles on detail / category browse screens (larger, matches AppBar weight/color).
TextStyle storefrontAppBarEmphasisTitleStyle(BuildContext context) {
  return storefrontHeroTitleStyle(context).copyWith(fontSize: 22);
}

/// Primary product name on the product detail body (below the image).
TextStyle storefrontProductNameStyle(BuildContext context) {
  return storefrontHeroTitleStyle(context).copyWith(fontSize: 24);
}
