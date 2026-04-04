import 'package:flutter/material.dart';

/// Responsive sizes for mixed home layouts (Flipkart / Amazon–style).
abstract final class HomeLayoutMetrics {
  static double heroHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.38).clamp(160.0, 200.0);
  }

  /// Standard horizontal rail (Popular).
  static double popularCardWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.40).clamp(150.0, 170.0);
  }

  /// Square image (1:1) + text block.
  static double popularRailHeight(double cardWidth) => cardWidth + 96;

  /// Larger personalized rail (Recommended).
  static double recommendedCardWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.54).clamp(200.0, 220.0);
  }

  /// **4:5** image area height = [cardWidth] * 5/4 + meta (title, price, CTA).
  static double recommendedImageHeight(double cardWidth) => cardWidth * 5 / 4;

  static double recommendedRailHeight(double cardWidth) =>
      recommendedImageHeight(cardWidth) + 136;

  /// Wide festival promo cards.
  static double festivalCardWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.82).clamp(260.0, 300.0);
  }

  static double festivalCardHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.24).clamp(160.0, 180.0);
  }

  static double festivalRailHeight(BuildContext context) =>
      festivalCardHeight(context) + 4;

  /// Category circles (Shop by category).
  static double categoryIconSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.19).clamp(72.0, 80.0);
  }

  static int newArrivalsColumnCount(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 420 ? 3 : 2;
  }

  static const double newArrivalRowExtent = 240;
  static const int newArrivalsMaxPreview = 12;

  static double newArrivalsGridHeight({
    required int itemCount,
    required int crossAxisCount,
    double rowExtent = newArrivalRowExtent,
    double mainAxisSpacing = 12,
  }) {
    if (itemCount <= 0) return 0;
    final rows = (itemCount + crossAxisCount - 1) ~/ crossAxisCount;
    return rows * rowExtent + (rows - 1) * mainAxisSpacing;
  }

  static double newArrivalCardWidth(BuildContext context, int columns) {
    final w = MediaQuery.sizeOf(context).width;
    const pad = 16.0;
    const gap = 12.0;
    return (w - pad * 2 - gap * (columns - 1)) / columns;
  }
}
