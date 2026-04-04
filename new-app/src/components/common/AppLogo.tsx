import React from 'react';
import { View, StyleSheet, Image } from 'react-native';
import { Text } from 'react-native-paper';
import { APP_LOGO } from '@/constants/branding';
import { sanctuaryColors, typography, spacing } from '@/theme';

interface AppLogoProps {
  size?: 'small' | 'medium' | 'large';
  showText?: boolean;
  variant?: 'default' | 'light' | 'dark';
}

const logoDimensions = {
  small: { height: 28, width: 90 },
  medium: { height: 36, width: 116 },
  large: { height: 48, width: 154 },
};

export default function AppLogo({
  size = 'medium',
  showText = true,
  variant = 'default',
}: AppLogoProps) {
  const dim = logoDimensions[size];

  const taglineColor =
    variant === 'dark' ? sanctuaryColors.lotusWhite : sanctuaryColors.deepGold;

  return (
    <View style={styles.container}>
      <Image
        source={APP_LOGO}
        style={{ height: dim.height, width: dim.width }}
        resizeMode="contain"
        accessibilityLabel="ANJANAM"
        accessible
      />
      {showText && (
        <View style={styles.textContainer}>
          <Text style={[styles.tagline, { color: taglineColor }]}>World Knowledge</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  textContainer: {
    alignItems: 'flex-start',
    justifyContent: 'center',
  },
  tagline: {
    ...typography.caption,
    fontWeight: '500',
    letterSpacing: 0.6,
  },
});
