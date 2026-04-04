
import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Image, Dimensions, Alert, ActivityIndicator } from 'react-native';
import { Text, Button, Chip, Divider, IconButton, useTheme, Snackbar } from 'react-native-paper';
import { StackActions, useNavigation, useRoute } from '@react-navigation/native';
import { useQuery } from '@apollo/client';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { GET_BOOK } from '@/graphql/queries/books';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import { API_CONFIG } from '@/constants';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { addToCart } from '@/store/slices/cartSlice';
import { addToWishlist, removeFromWishlist } from '@/store/slices/wishlistSlice';
import { setBuyNowItem } from '@/store/slices/buyNowSlice';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import ErrorMessage from '@/components/common/ErrorMessage';
import { fixImageUrl } from '@/utils/url';
const { width } = Dimensions.get('window');

export default function BookDetailScreen() {
  const navigation = useNavigation();
  const route = useRoute();
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const { bookId } = (route.params as any) || {};

  const { data, loading, error } = useQuery(GET_BOOK, {
    variables: {
      id: bookId,
      channel: API_CONFIG.SALEOR_CHANNEL
    },
    skip: !bookId,
  });

  const [quantity, setQuantity] = useState(1);
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  const [imageLoading, setImageLoading] = useState(true);
  const [imageError, setImageError] = useState(false);

  const wishlistItems = useAppSelector((state) => state.wishlist.items);
  const isInWishlist = wishlistItems.some(
    (wishItem) => wishItem.type === 'book' && wishItem.itemId === bookId
  );
  const cartItems = useAppSelector((state) => state.cart.cart.items);
  const isInCart = cartItems.some((item) => item.product.id === bookId);

  if (loading) {
    return <LoadingSpinner message="Loading book details..." />;
  }

  if (error || !data?.product) {
    return (
      <View style={styles.container}>
        <ErrorMessage
          message="Failed to load book details"
          onRetry={() => navigation.goBack()}
        />
      </View>
    );
  }

  const book = data.product;
  const variant = book.defaultVariant || {};
  const authorAttr = book.attributes?.find((a: any) => a.attribute.slug === 'author');
  const pagesAttr = book.attributes?.find((a: any) => a.attribute.slug === 'pages');
  const languageAttr = book.attributes?.find((a: any) => a.attribute.slug === 'language');
  const publisherAttr = book.attributes?.find((a: any) => a.attribute.slug === 'publisher');
  const isbnAttr = book.attributes?.find((a: any) => a.attribute.slug === 'isbn');

  const author = authorAttr?.values[0]?.name || 'Unknown Author';
  const pages = pagesAttr?.values[0]?.name || 'Unknown';
  const language = languageAttr?.values[0]?.name || 'English';
  const publisher = publisherAttr?.values[0]?.name || 'Unknown';
  const isbn = isbnAttr?.values[0]?.name || 'N/A';
  const price = variant.pricing?.price?.gross?.amount || 0;
  const currency = variant.pricing?.price?.gross?.currency || 'INR';
  // Get actual stock from Saleor backend
  const stockQuantity = variant.quantityAvailable || 0;
  const inStock = variant.quantityAvailable > 0 && book.isAvailable !== false;

  const createBookProduct = () => ({
    id: bookId,
    name: book.name,
    description: book.description || '',
    price,
    currency,
    images: [{ id: '1', url: book.thumbnail?.url || '', alt: book.name }],
    category: { id: '1', name: book.category?.name || 'Books', slug: 'books' },
    rating: 4.5,
    reviewCount: 0,
    inStock,
    stockQuantity,
    slug: bookId,
    createdAt: new Date().toISOString(),
    attributes: [],
    variants: [],
  });

  const handleToggleWishlist = () => {
    const bookItem = {
      id: bookId,
      name: book.name,
      description: book.description || '',
      price,
      currency,
      image: book.thumbnail?.url || '',
      images: [book.thumbnail?.url],
      category: book.category?.name || 'Books',
      rating: 4.5,
      reviewCount: 0,
      inStock,
      stockQuantity,
      slug: bookId,
      createdAt: new Date().toISOString(),
      attributes: [],
      variants: [],
    };

    if (isInWishlist) {
      // Find the wishlist item to get its ID
      const wishlistItem = wishlistItems.find(
        (item) => item.type === 'book' && item.itemId === bookId
      );
      if (wishlistItem) {
        dispatch(removeFromWishlist(wishlistItem.id));
      }
    } else {
      dispatch(addToWishlist({ type: 'book', item: bookItem }));
    }
  };

  const handleAddToCart = () => {
    if (!inStock) {
      setSnackbarMessage('This book is currently out of stock');
      setSnackbarVisible(true);
      return;
    }

    const bookProduct = createBookProduct();
    dispatch(addToCart({ product: bookProduct, quantity }));
    setSnackbarMessage(`Added ${quantity} ${quantity === 1 ? 'copy' : 'copies'} to cart`);
    setSnackbarVisible(true);
  };

  const handleBuyNow = () => {
    if (!inStock) {
      setSnackbarMessage('This book is currently out of stock');
      setSnackbarVisible(true);
      return;
    }

    const bookProduct = createBookProduct();
    const buyNowLine = { product: bookProduct as any, quantity };
    dispatch(setBuyNowItem(buyNowLine));
    (navigation as any).dispatch(
      StackActions.push('CheckoutAddress', { flow: 'buy_now', buyNowLine })
    );
  };

  const handleQuantityChange = (delta: number) => {
    const newQuantity = quantity + delta;
    const maxQuantity = Math.min(10, stockQuantity);

    if (delta > 0) {
      // Increasing quantity
      if (newQuantity > maxQuantity) {
        if (stockQuantity <= quantity) {
          setSnackbarMessage(`Only ${stockQuantity} items available in stock`);
          setSnackbarVisible(true);
        } else {
          setSnackbarMessage(`Maximum ${maxQuantity} items allowed per order`);
          setSnackbarVisible(true);
        }
        return;
      }
    } else {
      // Decreasing quantity
      if (newQuantity < 1) {
        setSnackbarMessage('Minimum quantity is 1');
        setSnackbarVisible(true);
        return;
      }
    }

    setQuantity(newQuantity);
  };

  return (
    <View style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Book Cover */}
        <View style={styles.coverContainer}>
          <View style={styles.imageWrapper}>
            <Image
              source={{
                uri: (() => {
                  // Try multiple image sources with proper URL handling
                  const thumbnail = book.thumbnail?.url;
                  const media = book.media?.[0]?.url;

                  if (thumbnail) {
                    return fixImageUrl(thumbnail);
                  }

                  if (media) {
                    return fixImageUrl(media);
                  }

                  // Fallback to a book-specific placeholder
                  return 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=300&h=450&fit=crop&auto=format';
                })()
              }}
              style={styles.coverImage}
              resizeMode="cover"
              onError={(error) => {
                console.log('Book image failed to load:', error.nativeEvent);
                setImageError(true);
                setImageLoading(false);
              }}
              onLoad={() => {
                console.log('Book image loaded successfully');
                setImageLoading(false);
                setImageError(false);
              }}
              onLoadStart={() => {
                console.log('Book image loading started');
                setImageLoading(true);
                setImageError(false);
              }}
            />

            {/* Loading indicator */}
            {imageLoading && (
              <View style={styles.loadingOverlay}>
                <ActivityIndicator size="large" color={theme.colors.primary} />
              </View>
            )}

            {/* Wishlist button overlay */}
            <View style={styles.imageOverlay}>
              <IconButton
                icon={isInWishlist ? 'heart' : 'heart-outline'}
                size={24}
                iconColor={isInWishlist ? theme.colors.error : '#FFFFFF'}
                style={styles.wishlistButton}
                onPress={handleToggleWishlist}
              />
            </View>
          </View>
        </View>

        <View style={styles.contentContainer}>
          {/* Category */}
          <Chip icon="tag" mode="outlined" style={styles.categoryChip}>
            {book.category?.name || 'Book'}
          </Chip>

          {/* Title */}
          <Text variant="headlineMedium" style={styles.title}>
            {book.name}
          </Text>

          {/* Author */}
          <Text variant="titleMedium" style={styles.author}>
            by {author}
          </Text>

          {/* Rating & Pages */}
          <View style={styles.metaRow}>
            <View style={styles.metaItem}>
              <MaterialCommunityIcons name="star" size={20} color="#FFC107" />
              <Text variant="bodyMedium" style={styles.metaText}>
                4.5
              </Text>
            </View>
            <Text style={styles.separator}>•</Text>
            <View style={styles.metaItem}>
              <MaterialCommunityIcons name="book-open-page-variant" size={20} color={theme.colors.primary} />
              <Text variant="bodyMedium" style={styles.metaText}>
                {pages} pages
              </Text>
            </View>
            <Text style={styles.separator}>•</Text>
            <View style={styles.metaItem}>
              <MaterialCommunityIcons name="translate" size={20} color={theme.colors.primary} />
              <Text variant="bodyMedium" style={styles.metaText}>
                {language}
              </Text>
            </View>
          </View>

          {/* Price */}
          <Text variant="headlineSmall" style={[styles.price, { color: theme.colors.primary }]}>
            {formatCurrency(price, currency)}
          </Text>

          <Divider style={styles.divider} />

          {/* Description */}
          <Text variant="titleMedium" style={styles.sectionTitle}>
            Description
          </Text>
          <Text variant="bodyMedium" style={styles.description}>
            {book.description || 'No description available.'}
          </Text>

          <Divider style={styles.divider} />

          {/* Details */}
          <Text variant="titleMedium" style={styles.sectionTitle}>
            Details
          </Text>
          <View style={styles.detailRow}>
            <Text variant="bodyMedium" style={styles.detailLabel}>
              Publisher:
            </Text>
            <Text variant="bodyMedium" style={styles.detailValue}>
              {publisher}
            </Text>
          </View>
          <View style={styles.detailRow}>
            <Text variant="bodyMedium" style={styles.detailLabel}>
              Language:
            </Text>
            <Text variant="bodyMedium" style={styles.detailValue}>
              {language}
            </Text>
          </View>
          <View style={styles.detailRow}>
            <Text variant="bodyMedium" style={styles.detailLabel}>
              Pages:
            </Text>
            <Text variant="bodyMedium" style={styles.detailValue}>
              {pages}
            </Text>
          </View>
          <View style={styles.detailRow}>
            <Text variant="bodyMedium" style={styles.detailLabel}>
              ISBN:
            </Text>
            <Text variant="bodyMedium" style={styles.detailValue}>
              {isbn}
            </Text>
          </View>

          {/* Stock Status */}
          <Divider style={styles.divider} />
          <View style={styles.stockRow}>
            <MaterialCommunityIcons
              name={inStock ? 'check-circle' : 'close-circle'}
              size={20}
              color={inStock ? '#4CAF50' : '#F44336'}
            />
            <Text variant="bodyMedium" style={[styles.stockText, { color: inStock ? '#4CAF50' : '#F44336' }]}>
              {inStock ? 'In Stock' : 'Out of Stock'}
            </Text>
          </View>

          <View style={styles.spacer} />
        </View>
      </ScrollView>

      {/* Add to Cart Section */}
      <View style={[styles.actionContainer, { backgroundColor: theme.colors.surface }]}>
        {/* Quantity Selector Row */}
        <View style={styles.quantityRow}>
          <Text variant="bodyMedium" style={styles.quantityLabel}>Qty:</Text>
          <View style={styles.quantityControls}>
            <IconButton
              icon="minus"
              size={20}
              onPress={() => handleQuantityChange(-1)}
              disabled={quantity <= 1}
              style={styles.quantityButton}
            />
            <Text variant="titleMedium" style={styles.quantityText}>
              {quantity}
            </Text>
            <IconButton
              icon="plus"
              size={20}
              onPress={() => handleQuantityChange(1)}
              disabled={quantity >= Math.min(10, stockQuantity) || !inStock}
              style={styles.quantityButton}
            />
          </View>

          {/* Stock Status */}
          <View style={styles.stockStatus}>
            {!inStock ? (
              <Text style={styles.outOfStockText}>Out of Stock</Text>
            ) : stockQuantity <= 5 ? (
              <Text style={styles.lowStockText}>Only {stockQuantity} left</Text>
            ) : null}
          </View>
        </View>

        {/* Action Buttons Row */}
        <View style={styles.actionButtonsRow}>
          {isInCart ? (
            <Button
              mode="contained-tonal"
              icon="cart"
              onPress={() => (navigation as any).navigate('Cart')}
              style={[styles.actionButton, styles.addToCartButton]}
              labelStyle={styles.addToCartLabel}
              compact
            >
              Go to Cart
            </Button>
          ) : (
            <Button
              mode="outlined"
              icon="cart-plus"
              onPress={handleAddToCart}
              disabled={!inStock}
              style={[styles.actionButton, styles.addToCartButton]}
              labelStyle={styles.addToCartLabel}
              compact
            >
              Add to Cart
            </Button>
          )}

          <Button
            mode="contained"
            icon="lightning-bolt"
            onPress={handleBuyNow}
            disabled={!inStock}
            style={[styles.actionButton, styles.buyNowButton]}
            labelStyle={styles.buyNowLabel}
            compact
          >
            Buy Now
          </Button>
        </View>
      </View>

      {/* Snackbar */}
      <Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={3000}
        action={{
          label: 'View Cart',
          onPress: () => (navigation as any).navigate('Cart'),
        }}
      >
        {snackbarMessage}
      </Snackbar>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  coverContainer: {
    alignItems: 'center',
    paddingVertical: spacing.xl,
    backgroundColor: '#F5F5F5',
  },
  imageWrapper: {
    position: 'relative',
    alignItems: 'center',
  },
  coverImage: {
    width: width * 0.5,
    height: width * 0.75,
    borderRadius: 12,
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    backgroundColor: '#F0F0F0', // Background color while loading
  },
  imageOverlay: {
    position: 'absolute',
    top: 0,
    right: 0,
    width: '100%',
    height: '100%',
    justifyContent: 'flex-start',
    alignItems: 'flex-end',
  },
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(240,240,240,0.8)',
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 12,
  },
  wishlistButton: {
    margin: spacing.md,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  contentContainer: {
    padding: spacing.md,
  },
  categoryChip: {
    alignSelf: 'flex-start',
    marginBottom: spacing.sm,
  },
  title: {
    fontWeight: '700',
    marginBottom: spacing.xs,
  },
  author: {
    opacity: 0.7,
    marginBottom: spacing.md,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  metaText: {
    opacity: 0.8,
  },
  separator: {
    marginHorizontal: spacing.sm,
    opacity: 0.5,
  },
  price: {
    fontWeight: '700',
    marginBottom: spacing.md,
  },
  divider: {
    marginVertical: spacing.md,
  },
  sectionTitle: {
    fontWeight: '600',
    marginBottom: spacing.sm,
  },
  description: {
    lineHeight: 24,
    opacity: 0.8,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  detailLabel: {
    opacity: 0.7,
  },
  detailValue: {
    fontWeight: '500',
  },
  spacer: {
    height: spacing.xl,
  },
  actionContainer: {
    padding: spacing.md,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
    gap: spacing.md,
  },
  actionButton: {
    flex: 1,
  },
  stockRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  stockText: {
    fontWeight: '600',
  },
  quantityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  quantityLabel: {
    fontWeight: '600',
  },
  quantityControls: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
  },
  quantityText: {
    minWidth: 40,
    textAlign: 'center',
    fontWeight: '600',
  },
  actionButtons: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  addToCartButton: {
    borderColor: '#2E7D32',
  },
  addToCartLabel: {
    color: '#2E7D32',
  },
  buyNowButton: {
    backgroundColor: '#FF6B35',
  },
  buyNowLabel: {
    color: '#FFFFFF',
  },
  quantityRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.md,
  },
  quantityButton: {
    margin: 0,
  },
  stockStatus: {
    flex: 1,
    alignItems: 'flex-end',
  },
  outOfStockText: {
    color: '#F44336',
    fontSize: 12,
    fontWeight: '600',
  },
  lowStockText: {
    color: '#FF9800',
    fontSize: 12,
    fontWeight: '500',
  },
  actionButtonsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
});
