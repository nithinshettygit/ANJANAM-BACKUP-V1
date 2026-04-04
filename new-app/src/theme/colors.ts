// ANJANAM Design System - "Sanctuary with Spiritual Spark"
// Colors inspired by betel leaf (green) with black dot representing world knowledge

export const sanctuaryColors = {
  // Primary Backgrounds - Calm Foundation
  lotusWhite: '#FDFBF5',        // App screens, panels—pure calm
  sandalwoodBeige: '#F3E9DD',   // All cards, overlays—natural calm
  
  // Brand Colors - Betel Leaf Identity
  forestGreen: '#2E7D32',       // Headers, highlights, main actions (betel leaf)
  darkGreen: '#1B5E20',         // Borders, shadows, navigation (leaf veins)
  sageGreen: '#6B8E23',         // Info icons, active switches, callouts
  
  // Accent Colors - Spiritual Spark
  deepGold: '#B8860B',          // Key action buttons, sale tags—luxurious accent
  royalBlue: '#264A99',         // Active tabs, links, icons—strong spiritual accent
  marigoldOrange: '#FFB300',    // Celebration, banners, secondary CTAs
  
  // Text Colors - Knowledge Symbol
  charcoalBlack: '#212121',     // Default text, headlines—knowledge symbol
  softBlack: '#1B1B1B',        // Secondary text, almost black—the dot
  warmGray: '#757575',          // Tertiary text, placeholders
  
  // Surface & Border Colors - Natural Depth
  mildBeige: '#E1D4C0',         // Visual depth for all cards
  lightBeige: '#F5F0E8',        // Subtle backgrounds, disabled states
  
  // Functional Colors
  successGreen: '#4CAF50',      // Success states
  warningAmber: '#FF9800',      // Warning states
  errorRed: '#F44336',          // Error states
  infoBlue: '#2196F3',          // Information states
  
  // Transparency Overlays
  blackOverlay: 'rgba(27, 27, 27, 0.6)',     // Modal backdrops
  greenOverlay: 'rgba(46, 125, 50, 0.1)',    // Hover states
  goldOverlay: 'rgba(184, 134, 11, 0.1)',    // Active states
};

export const gradients = {
  // Primary Gradients - Sanctuary Feel
  lotusToBeige: ['#FDFBF5', '#F3E9DD'],
  beigeToLotus: ['#F3E9DD', '#FDFBF5'],
  
  // Accent Gradients - Celebration
  goldToAmber: ['#B8860B', '#FFB300'],
  greenToSage: ['#2E7D32', '#6B8E23'],
  blueToGreen: ['#264A99', '#2E7D32'],
  
  // Subtle Gradients - Depth
  lightBeigeToWhite: ['#F5F0E8', '#FDFBF5'],
  whiteToBeige: ['#FFFFFF', '#F3E9DD'],
};

// Dark Mode Colors - Maintaining Spiritual Essence
export const darkSanctuaryColors = {
  // Dark Backgrounds
  deepCharcoal: '#121212',      // Main background
  warmCharcoal: '#1E1E1E',      // Surface background
  softCharcoal: '#2E2E2E',      // Card backgrounds
  
  // Brand Colors - Adapted for Dark
  lightGreen: '#A5D6A7',        // Primary green for dark mode
  mediumGreen: '#81C784',       // Secondary green
  paleGreen: '#C8E6C9',         // Tertiary green
  
  // Accent Colors - Softened for Dark
  softGold: '#FFD54F',          // CTAs in dark mode
  lightBlue: '#64B5F6',         // Active elements
  softOrange: '#FFB74D',        // Secondary accents
  
  // Text Colors - High Contrast
  lightText: '#E8F5E8',         // Primary text on dark
  mediumText: '#B8B8B8',        // Secondary text
  subtleText: '#757575',        // Tertiary text
  
  // Borders and Outlines
  darkBorder: '#424242',        // Card borders
  accentBorder: '#4CAF50',      // Active borders
};

export type ColorPalette = typeof sanctuaryColors;
export type DarkColorPalette = typeof darkSanctuaryColors;
