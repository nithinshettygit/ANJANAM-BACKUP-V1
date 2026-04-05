import 'package:flutter/material.dart';

/// ANJANAM design tokens — saffron / gold, calm cream surfaces, charcoal text.
///
/// Legacy names ([charcoalBlack], [deepGold], etc.) map to the same values where
/// noted so existing screens keep working while new code prefers explicit tokens.
class AppColors {
  // ——— Logo-derived system ———
  /// Primary brand — primary buttons, active states, key highlights.
  static const Color brandSaffron = Color(0xFFF28C18);
  /// Secondary accent — stars, small highlights, icon accents.
  static const Color brandGold = Color(0xFFD4A017);
  /// Pressed / darker saffron for hover states.
  static const Color brandSaffronPressed = Color(0xFFD97A0F);
  /// Links and strong emphasis on cream (readable on light bg).
  static const Color brandSaffronDeep = Color(0xFFC67610);
  /// Rupee amounts, totals, and sale prices on light backgrounds (high contrast vs [brandSaffron] / gold).
  static const Color priceText = Color(0xFF6B3A08);

  /// Main scaffold / page background.
  static const Color backgroundCream = Color(0xFFFFF7E8);
  /// Product cards, sheets, app bar.
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Primary body text.
  static const Color textPrimary = Color(0xFF222222);
  /// Section titles on home (slightly softer than pure black).
  static const Color sectionTitle = Color(0xFF2B2B2B);
  /// Secondary / captions.
  static const Color textSecondary = Color(0xFF666666);

  /// Hairlines, search border, dividers.
  static const Color borderSubtle = Color(0xFFE5E1DB);
  /// Search field fill (slightly warmer than page).
  static const Color searchFieldFill = Color(0xFFFFF2E6);

  // ——— Home “shelf” panels — distinct moods, same family as saffron / gold / cream ———
  /// Popular — warm **honey amber** (trending / energy).
  static const Color homeShelfPopularFill = Color(0xFFFFE8CC);
  static const Color homeShelfPopularBorder = Color(0xFFE29A4A);
  /// Recommended — **light gray** panel (neutral vs warm Popular / Festival).
  static const Color homeShelfRecommendedFill = Color(0xFFF2F2F2);
  static const Color homeShelfRecommendedBorder = Color(0xFFC8C8C8);
  /// Shelf glow for Recommended (neutral gray).
  static const Color homeShelfRecommendedShadowTint = Color(0xFF888888);
  /// Festival — **marigold coral** celebration wash (joyful, not cold pink).
  static const Color homeShelfFestivalFill = Color(0xFFFFEDE3);
  static const Color homeShelfFestivalBorder = Color(0xFFFF8F6B);
  /// Deeper coral for shelf glow (pairs with [homeShelfFestivalBorder]).
  static const Color homeShelfFestivalShadowTint = Color(0xFFFF7043);
  /// New arrivals — **fresh sage mist** (new stock, earthy with brand warmth).
  static const Color homeShelfNewArrivalsFill = Color(0xFFE6F2E9);
  static const Color homeShelfNewArrivalsBorder = Color(0xFF7CB89A);

  // ——— Legacy & extended (customer + admin) ———
  static const Color primaryPurple = Color(0xFF6A1B9A);
  static const Color secondaryGray = backgroundCream;
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color textDark = textPrimary;
  static const Color pureWhite = surfaceCard;

  static const Color lotusWhite = backgroundCream;
  static const Color sandalwoodBeige = Color(0xFFF3EDE5);

  static const Color forestGreen = Color(0xFF2E7D32);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color sageGreen = Color(0xFF6B8E23);

  /// Same as [brandSaffron] (launcher / legacy callers).
  static const Color brandFlameOrange = brandSaffron;
  /// Same role as [brandSaffronDeep].
  static const Color brandAmberDark = brandSaffronDeep;

  static const Color deepGold = brandGold;
  static const Color royalBlue = Color(0xFF264A99);
  static const Color marigoldOrange = Color(0xFFF0C14B);

  static const Color charcoalBlack = textPrimary;
  static const Color softBlack = Color(0xFF1B1B1B);
  static const Color warmGray = textSecondary;

  static const Color mildBeige = Color(0xFFE1D4C0);
  static const Color lightBeige = Color(0xFFF5F0E8);

  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);

  static const Color deepCharcoal = Color(0xFF121212);
  static const Color warmCharcoal = Color(0xFF1E1E1E);
  static const Color softCharcoal = Color(0xFF2E2E2E);
  static const Color lightGreen = Color(0xFFA5D6A7);
  static const Color mediumGreen = Color(0xFF81C784);
  static const Color paleGreen = Color(0xFFC8E6C9);

  static const Color softGoldDark = Color(0xFFFFD54F);
  static const Color lightBlueDark = Color(0xFF64B5F6);
  static const Color softOrangeDark = Color(0xFFFFB74D);
  static const Color lightTextDark = Color(0xFFE8F5E8);
  static const Color mediumTextDark = Color(0xFFB8B8B8);
  static const Color subtleTextDark = Color(0xFF757575);
  static const Color darkBorderDark = Color(0xFF424242);
  static const Color accentBorderDark = Color(0xFF4CAF50);
}
