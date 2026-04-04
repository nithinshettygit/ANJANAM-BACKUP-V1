// ANJANAM Design System - Typography
// Elegant typography combining Lora (headlines) and Inter (body) for spiritual clarity

export const fontFamilies = {
  // Primary Font - Lora for Headlines (Elegant, Spiritual)
  headline: 'System',
  headlineBold: 'System',
  headlineSemiBold: 'System',
  
  // Secondary Font - Inter for Body Text (Clean, Modern)
  body: 'System',
  bodyBold: 'System',
  bodySemiBold: 'System',
  bodyMedium: 'System',
  
  // System Fallbacks
  systemFallback: 'System',
};

export const fontSizes = {
  // Headlines - Lora Font
  h1: 28,           // Major page titles
  h2: 24,           // Section headers
  h3: 22,           // Subsection headers
  h4: 20,           // Card titles
  h5: 18,           // Small headers
  h6: 16,           // Tiny headers
  
  // Body Text - Inter Font
  bodyLarge: 16,    // Primary body text
  bodyMedium: 15,   // Secondary body text
  bodySmall: 14,    // Tertiary body text
  
  // UI Elements
  button: 16,       // Button text
  caption: 12,      // Captions, labels
  overline: 10,     // Overline text
  
  // Navigation
  tabLabel: 14,     // Tab navigation
  tabLabelActive: 16, // Active tab
};

export const fontWeights = {
  light: '300' as const,
  regular: '400' as const,
  medium: '500' as const,
  semiBold: '600' as const,
  bold: '700' as const,
  extraBold: '800' as const,
};

export const lineHeights = {
  tight: 1.2,       // Headlines
  normal: 1.4,      // Body text
  relaxed: 1.6,     // Reading text
  loose: 1.8,       // Captions
};

// Typography Styles - Ready to Use
export const typography = {
  // Headlines - Lora Font (Spiritual Elegance)
  h1: {
    fontFamily: fontFamilies.headlineBold,
    fontSize: fontSizes.h1,
    fontWeight: fontWeights.bold,
    lineHeight: fontSizes.h1 * lineHeights.tight,
    letterSpacing: -0.5,
  },
  h2: {
    fontFamily: fontFamilies.headlineBold,
    fontSize: fontSizes.h2,
    fontWeight: fontWeights.bold,
    lineHeight: fontSizes.h2 * lineHeights.tight,
    letterSpacing: -0.3,
  },
  h3: {
    fontFamily: fontFamilies.headlineSemiBold,
    fontSize: fontSizes.h3,
    fontWeight: fontWeights.semiBold,
    lineHeight: fontSizes.h3 * lineHeights.tight,
    letterSpacing: -0.2,
  },
  h4: {
    fontFamily: fontFamilies.headlineSemiBold,
    fontSize: fontSizes.h4,
    fontWeight: fontWeights.semiBold,
    lineHeight: fontSizes.h4 * lineHeights.normal,
    letterSpacing: 0,
  },
  h5: {
    fontFamily: fontFamilies.headline,
    fontSize: fontSizes.h5,
    fontWeight: fontWeights.medium,
    lineHeight: fontSizes.h5 * lineHeights.normal,
    letterSpacing: 0,
  },
  h6: {
    fontFamily: fontFamilies.headline,
    fontSize: fontSizes.h6,
    fontWeight: fontWeights.medium,
    lineHeight: fontSizes.h6 * lineHeights.normal,
    letterSpacing: 0,
  },
  
  // Body Text - Inter Font (Clean Clarity)
  bodyLarge: {
    fontFamily: fontFamilies.body,
    fontSize: fontSizes.bodyLarge,
    fontWeight: fontWeights.regular,
    lineHeight: fontSizes.bodyLarge * lineHeights.normal,
    letterSpacing: 0,
  },
  bodyMedium: {
    fontFamily: fontFamilies.body,
    fontSize: fontSizes.bodyMedium,
    fontWeight: fontWeights.regular,
    lineHeight: fontSizes.bodyMedium * lineHeights.normal,
    letterSpacing: 0,
  },
  bodySmall: {
    fontFamily: fontFamilies.body,
    fontSize: fontSizes.bodySmall,
    fontWeight: fontWeights.regular,
    lineHeight: fontSizes.bodySmall * lineHeights.normal,
    letterSpacing: 0.1,
  },
  
  // UI Elements
  buttonPrimary: {
    fontFamily: fontFamilies.bodySemiBold,
    fontSize: fontSizes.button,
    fontWeight: fontWeights.semiBold,
    lineHeight: fontSizes.button * lineHeights.tight,
    letterSpacing: 0.5,
    textTransform: 'none' as const,
  },
  buttonSecondary: {
    fontFamily: fontFamilies.bodyMedium,
    fontSize: fontSizes.button,
    fontWeight: fontWeights.medium,
    lineHeight: fontSizes.button * lineHeights.tight,
    letterSpacing: 0.3,
    textTransform: 'none' as const,
  },
  caption: {
    fontFamily: fontFamilies.body,
    fontSize: fontSizes.caption,
    fontWeight: fontWeights.regular,
    lineHeight: fontSizes.caption * lineHeights.relaxed,
    letterSpacing: 0.4,
  },
  overline: {
    fontFamily: fontFamilies.bodyMedium,
    fontSize: fontSizes.overline,
    fontWeight: fontWeights.medium,
    lineHeight: fontSizes.overline * lineHeights.loose,
    letterSpacing: 1.5,
    textTransform: 'uppercase' as const,
  },
  
  // Navigation
  tabLabel: {
    fontFamily: fontFamilies.bodyMedium,
    fontSize: fontSizes.tabLabel,
    fontWeight: fontWeights.medium,
    lineHeight: fontSizes.tabLabel * lineHeights.tight,
    letterSpacing: 0.2,
  },
  tabLabelActive: {
    fontFamily: fontFamilies.bodySemiBold,
    fontSize: fontSizes.tabLabelActive,
    fontWeight: fontWeights.semiBold,
    lineHeight: fontSizes.tabLabelActive * lineHeights.tight,
    letterSpacing: 0.2,
  },
  
  // Special Text Styles
  price: {
    fontFamily: fontFamilies.bodySemiBold,
    fontSize: fontSizes.bodyLarge,
    fontWeight: fontWeights.semiBold,
    lineHeight: fontSizes.bodyLarge * lineHeights.tight,
    letterSpacing: 0,
  },
  priceStrike: {
    fontFamily: fontFamilies.body,
    fontSize: fontSizes.bodySmall,
    fontWeight: fontWeights.regular,
    lineHeight: fontSizes.bodySmall * lineHeights.tight,
    letterSpacing: 0,
    textDecorationLine: 'line-through' as const,
  },
  badge: {
    fontFamily: fontFamilies.bodySemiBold,
    fontSize: fontSizes.caption,
    fontWeight: fontWeights.semiBold,
    lineHeight: fontSizes.caption * lineHeights.tight,
    letterSpacing: 0.5,
    textTransform: 'uppercase' as const,
  },
};

export type Typography = typeof typography;
