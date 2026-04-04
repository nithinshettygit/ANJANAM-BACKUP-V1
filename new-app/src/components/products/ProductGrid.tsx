import React from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { Product } from '@/types';
import ProductCard from './ProductCard';
import { spacing } from '@/theme';
import EmptyState from '../common/EmptyState';

interface ProductGridProps {
  products: Product[];
  onProductPress: (product: Product) => void;
  onRefresh?: () => void;
  refreshing?: boolean;
  onEndReached?: () => void;
  ListHeaderComponent?: React.ReactElement;
}

export default function ProductGrid({
  products,
  onProductPress,
  onRefresh,
  refreshing = false,
  onEndReached,
  ListHeaderComponent,
}: ProductGridProps) {
  const renderItem = ({ item }: { item: Product }) => (
    <View style={styles.itemContainer}>
      <ProductCard product={item} onPress={() => onProductPress(item)} />
    </View>
  );

  if (products.length === 0 && !refreshing) {
    return (
      <EmptyState
        icon="shopping-outline"
        title="No Products Found"
        message="We couldn't find any products matching your criteria. Try adjusting your filters."
      />
    );
  }

  return (
    <FlatList
      data={products}
      renderItem={renderItem}
      keyExtractor={(item) => item.id}
      numColumns={2}
      contentContainerStyle={styles.container}
      columnWrapperStyle={styles.row}
      showsVerticalScrollIndicator={false}
      onRefresh={onRefresh}
      refreshing={refreshing}
      onEndReached={onEndReached}
      onEndReachedThreshold={0.5}
      ListHeaderComponent={ListHeaderComponent}
    />
  );
}

const styles = StyleSheet.create({
  container: {
    padding: spacing.md,
  },
  row: {
    justifyContent: 'space-between',
    alignItems: 'flex-start', // Align items to top
  },
  itemContainer: {
    flex: 1,
    maxWidth: '48%',
    marginBottom: spacing.md, // Consistent bottom margin
  },
});
