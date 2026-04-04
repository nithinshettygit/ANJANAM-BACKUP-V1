import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { Searchbar, useTheme } from 'react-native-paper';
import { spacing } from '@/theme';

interface SearchBarProps {
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  autoFocus?: boolean;
}

export default function SearchBar({ placeholder = 'Search products...', onChangeText, value, autoFocus = false }: SearchBarProps) {
  const theme = useTheme();

  return (
    <View style={styles.container}>
      <Searchbar
        placeholder={placeholder || 'Search...'}
        onChangeText={onChangeText}
        value={value}
        autoFocus={autoFocus}
        style={[styles.searchbar, { backgroundColor: theme.colors.surface }]}
        iconColor={theme.colors.primary}
        elevation={2}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  searchbar: {
    borderRadius: 12,
  },
});
