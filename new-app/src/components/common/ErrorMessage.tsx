import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Text, Button } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { spacing, sanctuaryColors, typography, componentShadows, shadows } from '@/theme';

interface ErrorMessageProps {
  message: string;
  onRetry?: () => void;
}

export default function ErrorMessage({ message, onRetry }: ErrorMessageProps) {
  return (
    <View style={styles.container}>
      <View style={styles.iconContainer}>
        <MaterialCommunityIcons name="alert-circle-outline" size={64} color={sanctuaryColors.errorRed} />
      </View>
      <Text style={styles.title}>
        Oops! Something went wrong
      </Text>
      <Text style={styles.message}>
        {message}
      </Text>
      {onRetry && (
        <Button 
          mode="contained" 
          onPress={onRetry} 
          style={styles.button}
          buttonColor={sanctuaryColors.deepGold}
          textColor="#FFFFFF"
        >
          Try Again
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
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: sanctuaryColors.lightBeige,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.md,
    ...shadows.gentle,
  },
  title: {
    ...typography.h4,
    marginTop: spacing.md,
    marginBottom: spacing.sm,
    textAlign: 'center',
    color: sanctuaryColors.charcoalBlack,
  },
  message: {
    ...typography.bodyMedium,
    marginBottom: spacing.lg,
    textAlign: 'center',
    color: sanctuaryColors.warmGray,
    maxWidth: 280,
  },
  button: {
    marginTop: spacing.md,
    ...componentShadows.button,
  },
});
