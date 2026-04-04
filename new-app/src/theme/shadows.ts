// ANJANAM Design System - Shadows & Depth
// Creating spiritual depth with subtle, natural shadows

export const shadows = {
  // Subtle Shadows - Gentle Depth
  whisper: {
    shadowColor: '#1B1B1B',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  
  // Small Shadows - Card Depth
  gentle: {
    shadowColor: '#1B1B1B',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  
  // Medium Shadows - Component Separation
  soft: {
    shadowColor: '#1B1B1B',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 8,
    elevation: 4,
  },
  
  // Large Shadows - Modal/Floating Elements
  medium: {
    shadowColor: '#1B1B1B',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.16,
    shadowRadius: 16,
    elevation: 8,
  },
  
  // Extra Large Shadows - Major Floating Elements
  strong: {
    shadowColor: '#1B1B1B',
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.20,
    shadowRadius: 24,
    elevation: 12,
  },
  
  // Dramatic Shadows - Hero Elements
  dramatic: {
    shadowColor: '#1B1B1B',
    shadowOffset: { width: 0, height: 16 },
    shadowOpacity: 0.24,
    shadowRadius: 32,
    elevation: 16,
  },
};

// Colored Shadows for Special Elements
export const coloredShadows = {
  // Green Shadows - Brand Elements
  greenGlow: {
    shadowColor: '#2E7D32',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 4,
  },
  
  // Gold Shadows - CTA Elements
  goldGlow: {
    shadowColor: '#B8860B',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.20,
    shadowRadius: 8,
    elevation: 4,
  },
  
  // Blue Shadows - Active Elements
  blueGlow: {
    shadowColor: '#264A99',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.18,
    shadowRadius: 8,
    elevation: 4,
  },
  
  // Success Shadow
  successGlow: {
    shadowColor: '#4CAF50',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.12,
    shadowRadius: 6,
    elevation: 3,
  },
  
  // Error Shadow
  errorGlow: {
    shadowColor: '#F44336',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 6,
    elevation: 3,
  },
};

// Inner Shadows (for pressed states)
export const innerShadows = {
  pressed: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: -1, // Negative elevation for inner shadow effect
  },
};

// Shadow Presets for Common Components
export const componentShadows = {
  card: shadows.gentle,
  button: shadows.soft,
  modal: shadows.strong,
  fab: shadows.medium,
  appBar: shadows.whisper,
  bottomSheet: shadows.dramatic,
  tooltip: shadows.soft,
  dropdown: shadows.medium,
  
  // Interactive States
  cardHover: shadows.soft,
  buttonPressed: innerShadows.pressed,
  cardPressed: innerShadows.pressed,
  
  // Brand Specific
  primaryButton: coloredShadows.goldGlow,
  brandCard: coloredShadows.greenGlow,
  activeTab: coloredShadows.blueGlow,
  successCard: coloredShadows.successGlow,
  errorCard: coloredShadows.errorGlow,
};

export type ShadowStyle = typeof shadows.gentle;
export type ComponentShadows = typeof componentShadows;
