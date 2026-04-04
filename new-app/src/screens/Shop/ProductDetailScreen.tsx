import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Image, Dimensions } from 'react-native';
import { fixImageUrl } from '@/utils/url';
import { Text, Button, Chip, Divider, IconButton, useTheme, Snackbar } from 'react-native-paper';
import { StackActions, useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { useQuery } from '@apollo/client';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { RootStackParamList, Product, ProductVariant } from '@/types';
import { API_CONFIG } from '@/constants';
import { GET_PRODUCT } from '@/graphql/queries/products';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { addToCart } from '@/store/slices/cartSlice';
import { addToWishlist, removeFromWishlist } from '@/store/slices/wishlistSlice';
import { setBuyNowItem } from '@/store/slices/buyNowSlice';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import ErrorMessage from '@/components/common/ErrorMessage';

type NavigationProp = StackNavigationProp<RootStackParamList, 'ProductDetail'>;
type RoutePropType = RouteProp<RootStackParamList, 'ProductDetail'>;

const { width } = Dimensions.get('window');

export default function ProductDetailScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RoutePropType>();
  const theme = useTheme();
  const dispatch = useAppDispatch();

  const { productId } = route.params;

  // ALL HOOKS MUST BE AT THE TOP - BEFORE ANY CONDITIONAL RETURNS
  const [quantity, setQuantity] = useState(1);
  const [selectedVariant, setSelectedVariant] = useState<ProductVariant | undefined>();
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');

  const wishlistItems = useAppSelector((state) => state.wishlist.items);
  const cartItems = useAppSelector((state) => state.cart.cart.items);

  // Fetch product from backend
  const { data, loading, error } = useQuery(GET_PRODUCT, {
    variables: {
      id: productId,
      channel: API_CONFIG.SALEOR_CHANNEL
    },
    skip: !productId,
  });

  // Transform backend data safely
  const variant = data?.product?.defaultVariant || {};
  const thumbnailUrl = (() => {
    const primaryImage = data?.product?.thumbnail?.url;
    if (primaryImage) {
      return fixImageUrl(primaryImage);
    }
    return 'https://via.placeholder.com/400x400';
  })();

  // Get actual stock data from Saleor backend
  const stockQuantity = variant.quantityAvailable || 0;
  const inStock = stockQuantity > 0 && data?.product?.isAvailable !== false;

  const product: Product | null = data?.product ? {
    id: data.product.id,
    name: data.product.name,
    description: data.product.description || '',
    price: variant.pricing?.price?.gross?.amount || 0,
    currency: variant.pricing?.price?.gross?.currency || 'INR',
    images: [
      { id: '1', url: thumbnailUrl, alt: data.product.name },
      ...data.product.media?.map((m: any) => {
        const fixedUrl = fixImageUrl(m.url);
        return {
          id: m.id,
          url: fixedUrl || thumbnailUrl,
          alt: data.product.name,
          type: 'image'
        };
      }) || []
    ],
    category: {
      id: data.product.category?.id || 'unc',
      name: data.product.category?.name || 'Uncategorized',
      slug: data.product.category?.slug || 'uncategorized'
    },
    rating: 4.5,
    reviewCount: 0,
    inStock,
    stockQuantity,
    slug: data.product.id,
    createdAt: new Date().toISOString(),
    attributes: [],
    variants: data.product.variants?.map((v: any) => ({
      id: v.id,
      name: v.name,
      price: v.pricing?.price?.gross?.amount || 0,
      stockQuantity: v.quantityAvailable || 0,
      inStock: (v.quantityAvailable || 0) > 0,
      attributes: {},
    })) || [],
  } : null;

  const isInWishlist = wishlistItems.some(
    (item) => item.type === 'product' && item.itemId === productId
  );

  const isInCart = cartItems.some(
    (item) => item.product.id === productId
  );

  // Set default variant when product loads
  React.useEffect(() => {
    if (product?.variants && product.variants.length > 0 && !selectedVariant) {
      setSelectedVariant(product.variants[0]);
    }
  }, [product, selectedVariant]);

  if (loading) {
    return <LoadingSpinner message="Loading product details..." />;
  }

  if (error || !product) {
    return (
      <View style={styles.container}>
        <ErrorMessage
          message="Failed to load product details"
          onRetry={() => navigation.goBack()}
        />
      </View>
    );
  }

  const handleAddToCart = () => {
    dispatch(addToCart({ product, variant: selectedVariant, quantity }));
    setSnackbarMessage(`Added ${quantity} item(s) to cart`);
    setSnackbarVisible(true);
  };

  const handleBuyNow = () => {
    if (!product.inStock) {
      setSnackbarMessage('This product is currently out of stock');
      setSnackbarVisible(true);
      return;
    }

    const buyNowLine = { product, variant: selectedVariant, quantity };
    dispatch(setBuyNowItem(buyNowLine));

    navigation.dispatch(
      StackActions.push('CheckoutAddress', {
        flow: 'buy_now',
        buyNowLine,
      })
    );
  };

  const handleToggleWishlist = () => {
    if (isInWishlist) {
      const wishlistItem = wishlistItems.find(
        (item) => item.type === 'product' && item.itemId === productId
      );
      if (wishlistItem) {
        dispatch(removeFromWishlist(wishlistItem.id));
        setSnackbarMessage('Removed from wishlist');
      }
    } else {
      dispatch(addToWishlist({ type: 'product', item: product }));
      setSnackbarMessage('Added to wishlist');
    }
    setSnackbarVisible(true);
  };

  const handleQuantityChange = (delta: number) => {
    const newQuantity = Math.max(1, Math.min(quantity + delta, 10));
    setQuantity(newQuantity);
  };

  const currentPrice = selectedVariant?.price || product?.price || 0;
  const imageUrl = product?.images[0]?.url || 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=400&fit=crop';

  // Format description to be more readable (remove JSON-like formatting)
  const formatDescription = (desc: string) => {
    if (!desc) return 'No description available.';

    // Remove JSON-like formatting and clean up
    let formatted = desc
      .replace(/[{}[\]"]/g, '') // Remove JSON brackets and quotes
      .replace(/,\s*/g, '. ') // Replace commas with periods
      .replace(/:\s*/g, ': ') // Clean up colons
      .replace(/\s+/g, ' ') // Remove extra spaces
      .trim();

    // Capitalize first letter
    if (formatted.length > 0) {
      formatted = formatted.charAt(0).toUpperCase() + formatted.slice(1);
    }

    // Ensure it ends with a period
    if (formatted && !formatted.endsWith('.')) {
      formatted += '.';
    }

    return formatted || 'No description available.';
  };

  if (!product) {
    return null;
  }

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Product Image */}
        <View style={styles.imageContainer}>
          <Image
            source={{ uri: imageUrl }}
            style={styles.image}
            resizeMode="contain"
            onError={() => console.log('ProductDetail image failed to load:', imageUrl)}
          />
          {!product.inStock && (
            <View style={styles.outOfStockBadge}>
              <Text style={styles.outOfStockText}>Out of Stock</Text>
            </View>
          )}

          <IconButton
            icon={isInWishlist ? 'heart' : 'heart-outline'}
            iconColor={isInWishlist ? theme.colors.error : 'rgba(0,0,0,0.6)'}
            size={24}
            style={styles.wishlistButton}
            onPress={handleToggleWishlist}
            containerColor="rgba(255,255,255,0.8)"
          />
        </View>

        {/* Product Info */}
        <View style={styles.infoContainer}>
          {/* Category */}
          <Chip icon="tag" mode="outlined" style={styles.categoryChip}>
            {product.category.name}
          </Chip>

          {/* Name */}
          <Text variant="headlineSmall" style={styles.name}>
            {product.name}
          </Text>

          {/* Rating */}
          <View style={styles.ratingContainer}>
            <MaterialCommunityIcons name="star" size={20} color="#FFC107" />
            <Text variant="titleMedium" style={styles.rating}>
              {product.rating.toFixed(1)}
            </Text>
            <Text variant="bodyMedium" style={styles.reviewCount}>
              ({product.reviewCount} reviews)
            </Text>
          </View>

          {/* Price */}
          <Text variant="headlineMedium" style={[styles.price, { color: theme.colors.primary }]}>
            {formatCurrency(currentPrice, product.currency)}
          </Text>

          <Divider style={styles.divider} />

          {/* Variants */}
          {product.variants.length > 0 && (
            <View style={styles.section}>
              <Text variant="titleMedium" style={styles.sectionTitle}>
                Select Variant
              </Text>
              <View style={styles.variantsContainer}>
                {product.variants.map((variant: ProductVariant) => (
                  <Chip
                    key={variant.id}
                    selected={selectedVariant?.id === variant.id}
                    onPress={() => setSelectedVariant(variant)}
                    style={styles.variantChip}
                    disabled={!variant.inStock}
                  >
                    {variant.name}
                  </Chip>
                ))}
              </View>
            </View>
          )}

          {/* Quantity */}
          <View style={styles.section}>
            <Text variant="titleMedium" style={styles.sectionTitle}>
              Quantity
            </Text>
            <View style={styles.quantityContainer}>
              <IconButton
                icon="minus"
                size={20}
                onPress={() => handleQuantityChange(-1)}
                disabled={quantity <= 1}
              />
              <Text variant="titleLarge" style={styles.quantityText}>
                {quantity}
              </Text>
              <IconButton
                icon="plus"
                size={20}
                onPress={() => handleQuantityChange(1)}
                disabled={quantity >= 10}
              />
            </View>
          </View>

          <Divider style={styles.divider} />

          {/* Description */}
          <View style={styles.section}>
            <Text variant="titleMedium" style={styles.sectionTitle}>
              Description
            </Text>
            <Text variant="bodyMedium" style={styles.description}>
              {formatDescription(product.description)}
            </Text>
          </View>

          {/* Product Attributes */}
          {product.attributes && product.attributes.length > 0 && (
            <View>
              <Divider style={styles.divider} />
              <Text variant="titleMedium" style={styles.sectionTitle}>
                Specifications
              </Text>
              {product.attributes.map((attr: { id: string; name: string; value: string }) => (
                <View key={attr.id} style={styles.attributeRow}>
                  <Text variant="bodyMedium" style={styles.attributeName}>
                    {attr.name}:
                  </Text>
                  <Text variant="bodyMedium" style={styles.attributeValue}>
                    {attr.value}
                  </Text>
                </View>
              ))}
            </View>
          )}

          {/* Stock Info */}
          <View style={styles.section}>
            <View style={styles.stockInfo}>
              <MaterialCommunityIcons
                name={product.inStock ? 'check-circle' : 'close-circle'}
                size={20}
                color={product.inStock ? '#4CAF50' : '#F44336'}
              />
              <Text variant="bodyMedium" style={styles.stockText}>
                {product.inStock
                  ? `In Stock (${product.stockQuantity} available)`
                  : 'Out of Stock'}
              </Text>
            </View>
          </View>
        </View>
      </ScrollView >

      {/* Bottom Actions */}
      < View style={[styles.bottomActions, { backgroundColor: theme.colors.surface }]} >
        {
          isInCart ? (
            <>
              <Button
                mode="contained-tonal"
                icon="cart"
                onPress={() => navigation.navigate('Cart')}
                style={styles.actionButton}
              >
                Go to Cart
              </Button>
              <Button
                mode="contained"
                icon="lightning-bolt"
                onPress={handleBuyNow}
                disabled={!product.inStock}
                style={styles.actionButton}
              >
                Buy Now
              </Button>
            </>
          ) : (
            <>
              <Button
                mode="contained-tonal"
                icon="cart-plus"
                onPress={handleAddToCart}
                disabled={!product.inStock}
                style={styles.actionButton}
              >
                Add to Cart
              </Button>
              <Button
                mode="contained"
                icon="lightning-bolt"
                onPress={handleBuyNow}
                disabled={!product.inStock}
                style={styles.actionButton}
              >
                Buy Now
              </Button>
            </>
          )
        }
      </View >

      {/* Snackbar */}
      < Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={2000}
        action={{
          label: 'View Cart',
          onPress: () => navigation.navigate('Cart'),
        }}
      >
        {snackbarMessage}
      </Snackbar >
    </View >
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  imageContainer: {
    width: width,
    height: width,
    backgroundColor: '#F5F5F5',
    position: 'relative',
  },
  image: {
    width: '100%',
    height: '100%',
  },
  outOfStockBadge: {
    position: 'absolute',
    top: spacing.md,
    left: spacing.md,
    backgroundColor: '#F44336',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: 8,
  },
  outOfStockText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  wishlistButton: {
    position: 'absolute',
    top: spacing.md,
    right: spacing.md,
    margin: 0,
  },
  infoContainer: {
    padding: spacing.md,
  },
  categoryChip: {
    alignSelf: 'flex-start',
    marginBottom: spacing.sm,
  },
  name: {
    fontWeight: 'bold',
    marginBottom: spacing.sm,
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  rating: {
    marginLeft: spacing.xs,
    fontWeight: '600',
  },
  reviewCount: {
    marginLeft: spacing.xs,
    opacity: 0.7,
  },
  price: {
    fontWeight: 'bold',
    marginBottom: spacing.md,
  },
  divider: {
    marginVertical: spacing.md,
  },
  section: {
    marginBottom: spacing.md,
  },
  sectionTitle: {
    fontWeight: '600',
    marginBottom: spacing.sm,
  },
  variantsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  variantChip: {
    marginRight: spacing.xs,
    marginBottom: spacing.xs,
  },
  quantityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
  },
  quantityText: {
    marginHorizontal: spacing.md,
    fontWeight: '600',
  },
  description: {
    lineHeight: 24,
    opacity: 0.8,
  },
  attributeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: spacing.xs,
  },
  attributeName: {
    fontWeight: '600',
  },
  attributeValue: {
    opacity: 0.8,
  },
  stockInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  stockText: {
    marginLeft: spacing.sm,
  },
  bottomActions: {
    flexDirection: 'row',
    padding: spacing.md,
    gap: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  actionButton: {
    flex: 1,
  },
});
