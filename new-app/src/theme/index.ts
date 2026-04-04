import { MD3LightTheme, MD3DarkTheme, configureFonts } from 'react-native-paper';
import { sanctuaryColors, darkSanctuaryColors, gradients } from './colors';
import { typography, fontFamilies } from './typography';
import { shadows, componentShadows } from './shadows';
import { spacing, componentSpacing, layout, borderRadius, timing } from './spacing';

// ANJANAM "Sanctuary with Spiritual Spark" Design System
// Inspired by betel leaf (green) with black dot representing world knowledge

// Configure fonts for React Native Paper
const customFonts = configureFonts({
  config: {
    fontFamily: fontFamilies.systemFallback,
  },
});

// Light theme colors - Sanctuary palette (orange-forward for spiritual feel)
const lightColors = {
  primary: sanctuaryColors.deepGold,
  secondary: sanctuaryColors.marigoldOrange,
  tertiary: sanctuaryColors.forestGreen,
  success: sanctuaryColors.successGreen,
  warning: sanctuaryColors.warningAmber,
  error: sanctuaryColors.errorRed,
  info: sanctuaryColors.infoBlue,
  background: sanctuaryColors.lotusWhite,
  surface: sanctuaryColors.sandalwoodBeige,
  surfaceVariant: sanctuaryColors.lightBeige,
  onPrimary: '#FFFFFF',
  onSecondary: '#FFFFFF',
  onBackground: sanctuaryColors.charcoalBlack,
  onSurface: sanctuaryColors.charcoalBlack,
  outline: sanctuaryColors.mildBeige,
  shadow: sanctuaryColors.softBlack,
  inverseSurface: '#2E2E2E',
  inverseOnSurface: '#F4F4F4',
  inversePrimary: '#A5D6A7',
  backdrop: sanctuaryColors.blackOverlay,
  
  // Extended color palette
  accent: sanctuaryColors.deepGold,
  accentSecondary: sanctuaryColors.royalBlue,
  accentTertiary: sanctuaryColors.marigoldOrange,
  textSecondary: sanctuaryColors.warmGray,
  border: sanctuaryColors.mildBeige,
  cardBackground: '#FFFFFF',
  overlayBackground: sanctuaryColors.greenOverlay,
};

// Dark theme colors - Maintaining spiritual essence with warm accents
const darkColors = {
  primary: darkSanctuaryColors.softOrange,
  secondary: darkSanctuaryColors.softGold,
  tertiary: darkSanctuaryColors.lightGreen,
  success: sanctuaryColors.successGreen,
  warning: sanctuaryColors.warningAmber,
  error: sanctuaryColors.errorRed,
  info: sanctuaryColors.infoBlue,
  background: darkSanctuaryColors.deepCharcoal,
  surface: darkSanctuaryColors.warmCharcoal,
  surfaceVariant: darkSanctuaryColors.softCharcoal,
  onPrimary: darkSanctuaryColors.deepCharcoal,
  onSecondary: darkSanctuaryColors.deepCharcoal,
  onBackground: darkSanctuaryColors.lightText,
  onSurface: darkSanctuaryColors.lightText,
  outline: darkSanctuaryColors.darkBorder,
  shadow: '#000000',
  inverseSurface: sanctuaryColors.sandalwoodBeige,
  inverseOnSurface: sanctuaryColors.charcoalBlack,
  inversePrimary: sanctuaryColors.deepGold,
  backdrop: 'rgba(0, 0, 0, 0.7)',
  
  // Extended color palette
  accent: darkSanctuaryColors.softGold,
  accentSecondary: darkSanctuaryColors.lightBlue,
  accentTertiary: darkSanctuaryColors.softOrange,
  textSecondary: darkSanctuaryColors.mediumText,
  border: darkSanctuaryColors.darkBorder,
  cardBackground: darkSanctuaryColors.softCharcoal,
  overlayBackground: 'rgba(165, 214, 167, 0.1)',
};

// Complete Light Theme - Sanctuary with Spiritual Spark
export const lightTheme = {
  ...MD3LightTheme,
  colors: {
    ...MD3LightTheme.colors,
    ...lightColors,
  },
  fonts: customFonts,
  roundness: borderRadius.lg,
  
  // Extended theme properties
  typography,
  spacing,
  shadows,
  gradients,
  layout,
  borderRadius,
  timing,
  componentSpacing,
  componentShadows,
};

// Complete Dark Theme - Maintaining spiritual essence
export const darkTheme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    ...darkColors,
  },
  fonts: customFonts,
  roundness: borderRadius.lg,
  
  // Extended theme properties
  typography,
  spacing,
  shadows,
  gradients,
  layout,
  borderRadius,
  timing,
  componentSpacing,
  componentShadows,
};

// Export all design system modules for easy access
export {
  sanctuaryColors,
  darkSanctuaryColors,
  gradients,
} from './colors';

export {
  typography,
  fontFamilies,
  fontSizes,
  fontWeights,
  lineHeights,
} from './typography';

export {
  shadows,
  coloredShadows,
  componentShadows,
} from './shadows';

export {
  spacing,
  componentSpacing,
  layout,
  borderRadius,
  timing,
} from './spacing';

// Helper functions for theme usage
export const getGradient = (gradientName: keyof typeof gradients) => {
  return gradients[gradientName];
};

export const getShadow = (shadowName: keyof typeof componentShadows) => {
  return componentShadows[shadowName];
};

export const getSpacing = (spacingName: keyof typeof spacing) => {
  return spacing[spacingName];
};

// Theme utilities
export const createThemedStyles = (styleFunction: (theme: Theme) => any) => {
  return (theme: Theme) => styleFunction(theme);
};

export type Theme = typeof lightTheme;
