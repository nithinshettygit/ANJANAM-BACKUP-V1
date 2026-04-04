import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { Text } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { useQuery } from '@apollo/client';
import { SEARCH_PRODUCTS } from '@/graphql/queries/products';
import SearchBar from '@/components/products/SearchBar';
import ProductGrid from '@/components/products/ProductGrid';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import { Product } from '@/types';
import { API_CONFIG } from '@/constants';
import { spacing } from '@/theme';

export default function SearchScreen() {
  const navigation = useNavigation();
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');

  const { data, loading } = useQuery(SEARCH_PRODUCTS, {
    variables: { 
      search: debouncedQuery,
      first: 20,
      channel: API_CONFIG.SALEOR_CHANNEL
    },
    skip: !debouncedQuery,
  });

  const products = data?.products?.edges.map((edge: any) => {
    const node = edge.node;
    const variant = node.defaultVariant || {};
    const thumbnailUrl = node.thumbnail?.url || 'https://via.placeholder.com/400x400?text=Product';
    
    // Get actual stock data from Saleor backend
    const stockQuantity = variant.quantityAvailable || 0;
    const inStock = stockQuantity > 0 && node.isAvailable !== false;
    
    return {
      id: node.id,
      name: node.name,
      description: node.description || '',
      price: variant.pricing?.price?.gross?.amount || 0,
      currency: variant.pricing?.price?.gross?.currency || 'INR',
      images: [{ id: '1', url: thumbnailUrl, alt: node.name }],
      category: {
        id: node.category?.id || 'unc',
        name: node.category?.name || 'Uncategorized',
        slug: node.category?.slug || 'uncategorized'
      },
      rating: 4.5,
      reviewCount: 0,
      inStock,
      stockQuantity,
      slug: node.id,
      createdAt: new Date().toISOString(),
      attributes: [],
      variants: [],
    };
  }) || [];

  React.useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(searchQuery);
    }, 500);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  return (
    <View style={styles.container}>
      <SearchBar
        value={searchQuery}
        onChangeText={setSearchQuery}
        placeholder="Search all products..."
        autoFocus
      />
      
      {loading && <LoadingSpinner message="Searching..." />}
      
      {!loading && debouncedQuery && products.length === 0 && (
        <View style={styles.emptyState}>
          <Text variant="titleLarge">No results found</Text>
          <Text variant="bodyMedium">Try different keywords</Text>
        </View>
      )}
      
      {!loading && products.length > 0 && (
        <ProductGrid 
          products={products} 
          onProductPress={(product: Product) => {
            (navigation as any).navigate('ProductDetail', { productId: product.id });
          }}
          ListHeaderComponent={
            <Text style={styles.resultCount}>
              {products.length} {products.length === 1 ? 'result' : 'results'} found
            </Text>
          }
        />
      )}
      
      {!debouncedQuery && (
        <View style={styles.emptyState}>
          <Text variant="titleLarge">Start searching</Text>
          <Text variant="bodyMedium">Enter keywords to find products</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({ 
  container: { flex: 1 }, 
  emptyState: { 
    flex: 1, 
    justifyContent: 'center', 
    alignItems: 'center',
    padding: spacing.xl,
  },
  resultCount: {
    padding: spacing.md,
    paddingBottom: spacing.sm,
    opacity: 0.7,
  },
});
