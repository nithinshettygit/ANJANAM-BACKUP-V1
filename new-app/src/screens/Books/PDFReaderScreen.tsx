import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Text } from 'react-native-paper';
import { spacing } from '@/theme';

// This screen is not needed - books are physical products, not PDFs
export default function PDFReaderScreen() {
  return (
    <View style={styles.container}>
      <Text variant="titleLarge">PDF Reader Not Available</Text>
      <Text variant="bodyMedium">Books are physical products only</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  }
});
