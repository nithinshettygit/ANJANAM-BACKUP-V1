import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { Chip, useTheme } from 'react-native-paper';
import { spacing } from '@/theme';

interface Category {
  id: string;
  name: string;
  productCount?: number;
}

interface CategoryFilterProps {
  categories?: Category[];
  selectedCategory: string | null;
  onSelectCategory: (categoryName: string | null) => void;
}

export default function CategoryFilter({ categories = [], selectedCategory, onSelectCategory }: CategoryFilterProps) {
  const theme = useTheme();

  if (categories.length === 0) {
    return null;
  }

  return (
    <View style={styles.container}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {/* All Categories Chip */}
        <Chip
          selected={selectedCategory === null}
          onPress={() => onSelectCategory(null)}
          style={styles.chip}
          mode="flat"
        >
          All
        </Chip>

        {/* Category Chips */}
        {categories.map((category) => (
          <Chip
            key={category.id}
            selected={selectedCategory === category.name}
            onPress={() => onSelectCategory(category.name)}
            style={styles.chip}
            mode="flat"
          >
            {category.name}
          </Chip>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: spacing.sm,
  },
  scrollContent: {
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
  },
  chip: {
    marginRight: spacing.xs,
  },
});
