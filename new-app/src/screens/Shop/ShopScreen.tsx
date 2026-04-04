import React, { useState, useEffect, useMemo } from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar, Badge, Text } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { useQuery } from '@apollo/client';
import { RootStackParamList, Product } from '@/types';
import { API_CONFIG } from '@/constants';
import { GET_PRODUCTS, GET_CATEGORIES } from '@/graphql/queries/products';
import { spacing } from '@/theme';
import { useAppSelector } from '@/hooks/useTypedSelector';
import ProductGrid from '@/components/products/ProductGrid';
import SearchBar from '@/components/products/SearchBar';
import CategoryFilter from '@/components/products/CategoryFilter';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import ErrorMessage from '@/components/common/ErrorMessage';

type NavigationProp = StackNavigationProp<RootStackParamList>;

export default function ShopScreen() {
  const navigation = useNavigation<NavigationProp>();
  const cartItems = useAppSelector((state) => state.cart.cart.items);

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  // Fetch products from backend
  const { data, loading, error, refetch } = useQuery(GET_PRODUCTS, {
    variables: { 
      first: 50,
      channel: API_CONFIG.SALEOR_CHANNEL
    },
    fetchPolicy: 'cache-and-network',
  });

  // Fetch categories
  const { data: categoriesData } = useQuery(GET_CATEGORIES, {
    variables: { first: 20 },
  });

  // Transform backend data to match Product interface
  const products = data?.products?.edges.map((edge: any) => {
    const node = edge.node;
    const variant = node.defaultVariant || {};
    const thumbnailUrl = node.thumbnail?.url || 'https://via.placeholder.com/300';
    
    // Get actual stock data from Saleor backend
    const stockQuantity = variant.quantityAvailable || 0;
    const inStock = stockQuantity > 0 && node.isAvailable !== false;
    
    return {
      id: node.id,
      name: node.name,
      description: node.description || '',
      price: variant.pricing?.price?.gross?.amount || 0,
      currency: variant.pricing?.price?.gross?.currency || 'INR',
      images: [
        { id: '1', url: thumbnailUrl, alt: node.name },
        ...node.media?.map((m: any, idx: number) => ({ id: String(idx + 2), url: m.url, alt: node.name })) || []
      ],
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

  const categories = categoriesData?.categories?.edges.map((edge: any) => ({
    id: edge.node.id,
    name: edge.node.name,
    productCount: 0,
  })) || [];

  // Filter products based on search and category
  const filteredProducts = useMemo(() => {
    let result = products;

    // Apply category filter
    if (selectedCategory) {
      result = result.filter((p: Product) => p.category.name === selectedCategory);
    }

    // Apply search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (p: Product) =>
          p.name.toLowerCase().includes(query) ||
          p.description.toLowerCase().includes(query) ||
          p.category.name.toLowerCase().includes(query)
      );
    }

    return result;
  }, [products, searchQuery, selectedCategory]);

  const handleProductPress = (product: Product) => {
    navigation.navigate('ProductDetail', { productId: product.id });
  };

  const handleSearch = (query: string) => {
    setSearchQuery(query);
  };

  const handleCategorySelect = (categoryName: string | null) => {
    setSelectedCategory(categoryName);
  };

  const handleCartPress = () => {
    navigation.navigate('Cart');
  };

  const cartItemCount = cartItems.reduce((sum, item) => sum + item.quantity, 0);

  if (loading && !data) {
    return (
      <View style={styles.container}>
        <Appbar.Header elevated>
          <Appbar.Content title="ANJANAM SHOP" titleStyle={styles.title} />
        </Appbar.Header>
        <LoadingSpinner message="Loading products..." />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.container}>
        <Appbar.Header elevated>
          <Appbar.Content title="ANJANAM SHOP" titleStyle={styles.title} />
        </Appbar.Header>
        <ErrorMessage
          message="Failed to load products. Using offline mode."
          onRetry={() => refetch()}
        />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <Appbar.Header elevated>
        <Appbar.Content title="ANJANAM SHOP" titleStyle={styles.title} />
        <Appbar.Action 
          icon="cart" 
          onPress={handleCartPress}
        />
        {cartItems.length > 0 && (
          <Badge style={styles.badge}>{cartItems.length}</Badge>
        )}
      </Appbar.Header>

      {/* Search Bar */}
      <SearchBar
        value={searchQuery}
        onChangeText={handleSearch}
        placeholder="Search products..."
      />

      {/* Category Filter */}
      {categories.length > 0 && (
        <CategoryFilter
          categories={categories}
          selectedCategory={selectedCategory}
          onSelectCategory={handleCategorySelect}
        />
      )}

      {/* Products Grid - FlatList with built-in virtualization */}
      {filteredProducts.length > 0 ? (
        <ProductGrid 
          products={filteredProducts} 
          onProductPress={handleProductPress}
          onRefresh={() => refetch()}
          refreshing={loading}
          ListHeaderComponent={
            <Text style={styles.resultCount}>
              {filteredProducts.length} {filteredProducts.length === 1 ? 'product' : 'products'} found
            </Text>
          }
        />
      ) : (
        <View style={styles.emptyState}>
          <Text variant="titleLarge">No products found</Text>
          <Text variant="bodyMedium">Try adjusting your search or filters</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  title: {
    fontWeight: 'bold',
  },
  resultCount: {
    padding: spacing.md,
    paddingBottom: spacing.sm,
    opacity: 0.7,
  },
  badge: {
    position: 'absolute',
    top: 8,
    right: 8,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
    gap: spacing.sm,
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 16,
  },
});
