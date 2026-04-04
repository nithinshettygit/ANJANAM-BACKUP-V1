import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, RefreshControl, Image, Dimensions, TouchableOpacity } from 'react-native';
import { Appbar, Text, Chip, Searchbar, useTheme, Button, IconButton } from 'react-native-paper';
import { fixImageUrl } from '@/utils/url';
import { StackActions, useNavigation } from '@react-navigation/native';
import { useQuery } from '@apollo/client';
import { GET_BOOKS, GET_BOOK_CATEGORIES } from '@/graphql/queries/books';
import { spacing } from '@/theme';
import { API_CONFIG } from '@/constants';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import ErrorMessage from '@/components/common/ErrorMessage';
import EmptyState from '@/components/common/EmptyState';
import { formatCurrency } from '@/utils/format';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { addToCart } from '@/store/slices/cartSlice';
import { addToWishlist, removeFromWishlist } from '@/store/slices/wishlistSlice';
import { setBuyNowItem } from '@/store/slices/buyNowSlice';
import ProductCard from '@/components/products/ProductCard';

const { width } = Dimensions.get('window');
const CARD_WIDTH = (width - spacing.md * 3) / 2;

export default function BooksScreen() {
  const navigation = useNavigation();
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const cartItems = useAppSelector((state) => state.cart.cart.items);
  const wishlistItems = useAppSelector((state) => state.wishlist.items);

  // Fetch books from backend
  const { data, loading, error, refetch } = useQuery(GET_BOOKS, {
    variables: {
      first: 50,
      channel: API_CONFIG.SALEOR_CHANNEL
    },
    fetchPolicy: 'cache-and-network',
  });

  // Fetch categories
  const { data: categoriesData } = useQuery(GET_BOOK_CATEGORIES, {
    variables: { first: 20 },
  });

  // Transform backend data and filter for books
  const allProducts = data?.products?.edges || [];
  const books = allProducts
    .filter((edge: any) => {
      const category = edge.node.category?.name?.toLowerCase() || '';
      const name = edge.node.name?.toLowerCase() || '';
      // Filter for book-related products
      return category.includes('book') || name.includes('book') ||
        category.includes('literature') || category.includes('reading');
    })
    .map((edge: any) => {
      const node = edge.node;
      const variant = node.defaultVariant || {};
      const authorAttr = node.attributes?.find((a: any) => a.attribute.slug === 'author');
      const pagesAttr = node.attributes?.find((a: any) => a.attribute.slug === 'pages');

      // Get actual stock data from Saleor backend
      const stockQuantity = variant.quantityAvailable || 0;
      const inStock = stockQuantity > 0 && node.isAvailable !== false;

      return {
        id: node.id,
        name: node.name,
        description: node.description || '',
        price: variant.pricing?.price?.gross?.amount || 0,
        currency: variant.pricing?.price?.gross?.currency || 'INR',
        image: (() => {
          const primaryImage = node.thumbnail?.url;
          if (primaryImage) {
            return fixImageUrl(primaryImage);
          }
          return 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=300&h=450&fit=crop';
        })(),
        get images() {
          return [{ id: '1', url: this.image, alt: node.name, type: 'image' }];
        },
        category: {
          id: node.category?.id || 'books',
          name: node.category?.name || 'Uncategorized',
          slug: node.category?.slug || 'books'
        },
        author: authorAttr?.values[0]?.name || 'Unknown Author',
        pages: pagesAttr?.values[0]?.name || '0',
        stockQuantity,
        inStock,
        rating: 4.5,
      };
    });

  const categories = categoriesData?.categories?.edges.map((edge: any) => ({
    id: edge.node.id,
    name: edge.node.name,
    count: 0,
  })) || [];

  // Filter books
  const filteredBooks = React.useMemo(() => {
    let result = books;

    if (selectedCategory) {
      result = result.filter((b: any) => b.category === selectedCategory);
    }

    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (b: any) =>
          b.name.toLowerCase().includes(query) ||
          b.author.toLowerCase().includes(query) ||
          b.description.toLowerCase().includes(query)
      );
    }

    return result;
  }, [books, selectedCategory, searchQuery]);

  // Cart and wishlist handlers
  const handleAddToCart = (book: any) => {
    const bookProduct = {
      id: book.id,
      name: book.name,
      description: book.description,
      price: book.price,
      currency: book.currency,
      images: [{ id: '1', url: book.image, alt: book.name }],
      category: { id: 'books', name: book.category, slug: 'books' },
      rating: book.rating,
      reviewCount: 0,
      inStock: book.inStock,
      stockQuantity: book.stockQuantity,
      slug: book.id,
      createdAt: new Date().toISOString(),
      attributes: [],
      variants: [],
    };
    dispatch(addToCart({ product: bookProduct, quantity: 1 }));
  };

  const handleBuyNow = (book: any) => {
    const bookProduct = {
      id: book.id,
      name: book.name,
      description: book.description,
      price: book.price,
      currency: book.currency,
      images: [{ id: '1', url: book.image, alt: book.name, type: 'image' }], // Ensure structure matches
      category: { id: 'books', name: book.category, slug: 'books' },
      rating: book.rating,
      reviewCount: 0,
      inStock: book.inStock,
      stockQuantity: book.stockQuantity,
      slug: book.id,
      createdAt: new Date().toISOString(),
      attributes: [],
      variants: [],
    };

    const buyNowLine = { product: bookProduct as any, quantity: 1 };
    dispatch(setBuyNowItem(buyNowLine));
    (navigation as any).dispatch(
      StackActions.push('CheckoutAddress', { flow: 'buy_now', buyNowLine })
    );
  };

  const isInCart = (bookId: string) => {
    return cartItems.some(item => item.product.id === bookId);
  };

  const isInWishlist = (bookId: string) => {
    return wishlistItems.some(item => item.type === 'product' && item.itemId === bookId);
  };

  if (loading && !data) {
    return (
      <View style={styles.container}>
        <Appbar.Header elevated>
          <Appbar.Content title="Books" />
        </Appbar.Header>
        <LoadingSpinner message="Loading books..." />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.container}>
        <Appbar.Header elevated>
          <Appbar.Content title="Books" />
        </Appbar.Header>
        <ErrorMessage
          message="Failed to load books"
          onRetry={() => refetch()}
        />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Appbar.Header elevated>
        <Appbar.Content title="Books" />
      </Appbar.Header>

      {/* Search */}
      <View style={styles.searchContainer}>
        <Searchbar
          placeholder="Search books, authors..."
          onChangeText={setSearchQuery}
          value={searchQuery}
          style={styles.searchbar}
        />
      </View>

      {/* Categories */}
      {categories.length > 0 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.categoriesContainer}
          contentContainerStyle={styles.categoriesContent}
        >
          <Chip
            selected={selectedCategory === null}
            onPress={() => setSelectedCategory(null)}
            style={styles.categoryChip}
          >
            All
          </Chip>
          {categories.map((cat: any) => (
            <Chip
              key={cat.id}
              selected={selectedCategory === cat.name}
              onPress={() => setSelectedCategory(cat.name)}
              style={styles.categoryChip}
            >
              {cat.name}
            </Chip>
          ))}
        </ScrollView>
      )}

      <ScrollView
        style={styles.scrollView}
        refreshControl={
          <RefreshControl refreshing={loading} onRefresh={() => refetch()} />
        }
      >
        {filteredBooks.length > 0 ? (
          <>
            <Text style={styles.resultCount}>
              {filteredBooks.length} {filteredBooks.length === 1 ? 'book' : 'books'} found
            </Text>
            <View style={styles.grid}>
              {filteredBooks.map((book: any) => (
                <View key={book.id} style={{ width: CARD_WIDTH }}>
                  <ProductCard
                    product={book}
                    onPress={() =>
                      (navigation as any).navigate('BookDetail', { bookId: book.id })
                    }
                  />
                </View>
              ))}
            </View>
          </>
        ) : (
          <EmptyState
            icon="book-open-variant"
            title="No books found"
            message="Try adjusting your search or filters"
          />
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  searchContainer: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  searchbar: {
    elevation: 2,
  },
  categoriesContainer: {
    maxHeight: 60,
  },
  categoriesContent: {
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
  },
  categoryChip: {
    marginRight: spacing.sm,
  },
  scrollView: {
    flex: 1,
  },
  resultCount: {
    padding: spacing.md,
    paddingBottom: spacing.sm,
    opacity: 0.7,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: spacing.md,
    gap: spacing.md,
    justifyContent: 'space-between', // Ensure even spacing
  },
});
