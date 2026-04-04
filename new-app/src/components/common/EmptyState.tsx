import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Text, Button } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { spacing, sanctuaryColors, typography, componentShadows, shadows } from '@/theme';

interface EmptyStateProps {
  icon: keyof typeof MaterialCommunityIcons.glyphMap;
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
}

export default function EmptyState({
  icon,
  title,
  message,
  actionLabel,
  onAction,
}: EmptyStateProps) {
  return (
    <View style={styles.container}>
      <View style={styles.iconContainer}>
        <MaterialCommunityIcons name={icon} size={80} color={sanctuaryColors.sageGreen} />
      </View>
      <Text style={styles.title}>
        {title}
      </Text>
      <Text style={styles.message}>
        {message}
      </Text>
      {actionLabel && onAction && (
        <Button 
          mode="contained" 
          onPress={onAction} 
          style={styles.button}
          buttonColor={sanctuaryColors.deepGold}
          textColor="#FFFFFF"
        >
          {actionLabel}
        </Button>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
    backgroundColor: sanctuaryColors.lotusWhite,
  },
  iconContainer: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: sanctuaryColors.lightBeige,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.lg,
    ...shadows.gentle,
  },
  title: {
    ...typography.h3,
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
    textAlign: 'center',
    color: sanctuaryColors.charcoalBlack,
  },
  message: {
    ...typography.bodyMedium,
    marginBottom: spacing.lg,
    textAlign: 'center',
    color: sanctuaryColors.warmGray,
    maxWidth: 300,
    lineHeight: 22,
  },
  button: {
    marginTop: spacing.md,
    ...componentShadows.button,
  },
});
