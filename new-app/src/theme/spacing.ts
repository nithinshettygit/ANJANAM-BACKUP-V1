// ANJANAM Design System - Spacing & Layout
// Harmonious spacing system based on 4px grid for spiritual balance

export const spacing = {
  // Base spacing units (multiples of 4)
  none: 0,
  xs: 4,           // Tiny gaps
  sm: 8,           // Small gaps
  md: 16,          // Medium gaps (base unit)
  lg: 24,          // Large gaps
  xl: 32,          // Extra large gaps
  xxl: 48,         // Double extra large
  xxxl: 64,        // Triple extra large
  
  // Semantic spacing
  micro: 2,        // Borders, dividers
  tiny: 6,         // Icon spacing
  compact: 12,     // Compact layouts
  comfortable: 20, // Comfortable layouts
  spacious: 28,    // Spacious layouts
  generous: 40,    // Generous layouts
  luxurious: 56,   // Luxurious layouts
};

// Component-specific spacing
export const componentSpacing = {
  // Padding
  cardPadding: spacing.md,
  buttonPadding: {
    horizontal: spacing.lg,
    vertical: spacing.sm,
  },
  iconPadding: spacing.tiny,
  sectionPadding: spacing.lg,
  screenPadding: spacing.md,
  
  // Margins
  cardMargin: spacing.sm,
  sectionMargin: spacing.xl,
  itemMargin: spacing.xs,
  
  // Gaps
  listGap: spacing.sm,
  gridGap: spacing.md,
  flexGap: spacing.xs,
  
  // Specific measurements
  tabBarHeight: 60,
  appBarHeight: 56,
  bottomSheetHandle: 4,
  dividerHeight: 1,
  borderWidth: 1,
  focusBorderWidth: 2,
};

// Layout dimensions
export const layout = {
  // Container widths
  maxContentWidth: 1200,
  cardMaxWidth: 400,
  modalMaxWidth: 500,
  
  // Heights
  buttonHeight: {
    small: 32,
    medium: 40,
    large: 48,
    extraLarge: 56,
  },
  inputHeight: {
    small: 36,
    medium: 44,
    large: 52,
  },
  
  // Minimum touch targets (accessibility)
  minTouchTarget: 44,
  
  // Common component sizes
  avatarSize: {
    small: 32,
    medium: 40,
    large: 48,
    extraLarge: 64,
  },
  iconSize: {
    tiny: 12,
    small: 16,
    medium: 20,
    large: 24,
    extraLarge: 32,
    huge: 48,
  },
  
  // Product card dimensions
  productCard: {
    width: 160,
    height: 220,
    imageHeight: 120,
  },
  
  // Banner dimensions
  banner: {
    height: 200,
    borderRadius: 12,
  },
};

// Border radius system
export const borderRadius = {
  none: 0,
  xs: 2,           // Tiny radius
  sm: 4,           // Small radius
  md: 8,           // Medium radius (base)
  lg: 12,          // Large radius
  xl: 16,          // Extra large radius
  xxl: 24,         // Double extra large
  round: 9999,     // Fully rounded (pills, circles)
  
  // Component-specific
  button: 8,
  card: 12,
  input: 8,
  modal: 16,
  sheet: 24,
  avatar: 9999,
  badge: 16,
  chip: 20,
};

// Z-index system
export const zIndex = {
  base: 0,
  dropdown: 1000,
  sticky: 1020,
  fixed: 1030,
  modalBackdrop: 1040,
  modal: 1050,
  popover: 1060,
  tooltip: 1070,
  toast: 1080,
  loading: 1090,
};

// Animation timing
export const timing = {
  // Duration (milliseconds)
  instant: 0,
  fast: 150,
  normal: 250,
  slow: 350,
  slower: 500,
  
  // Easing curves
  easeOut: 'ease-out',
  easeIn: 'ease-in',
  easeInOut: 'ease-in-out',
  linear: 'linear',
  
  // Spring animations
  spring: {
    damping: 15,
    stiffness: 150,
  },
  
  // Common animation configs
  fadeIn: {
    duration: 250,
    easing: 'ease-out',
  },
  slideIn: {
    duration: 300,
    easing: 'ease-out',
  },
  scaleIn: {
    duration: 200,
    easing: 'ease-out',
  },
};

export type Spacing = typeof spacing;
export type ComponentSpacing = typeof componentSpacing;
export type Layout = typeof layout;
export type BorderRadius = typeof borderRadius;
