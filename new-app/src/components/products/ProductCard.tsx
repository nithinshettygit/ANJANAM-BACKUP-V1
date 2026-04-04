
import React, { useState } from 'react';
import { View, StyleSheet, TouchableOpacity, Image, Pressable } from 'react-native';
import { Card, Text, useTheme, IconButton, Badge } from 'react-native-paper';
import { StackActions, useNavigation } from '@react-navigation/native';
import { fixImageUrl } from '@/utils/url';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { Product } from '@/types';
import { formatCurrency } from '@/utils/format';
import { spacing, shadows, borderRadius } from '@/theme';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { addToCart } from '@/store/slices/cartSlice';
import { addToWishlist, removeFromWishlist } from '@/store/slices/wishlistSlice';
import { setBuyNowItem } from '@/store/slices/buyNowSlice';

interface ProductCardProps {
  product: Product;
  onPress: () => void;
}

const AnimatedCard = Animated.createAnimatedComponent(Card);
const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export default function ProductCard({ product, onPress }: ProductCardProps) {
  const theme = useTheme();
  const navigation = useNavigation<any>();
  const dispatch = useAppDispatch();
  const wishlistItems = useAppSelector((state) => state.wishlist.items);
  const [imageError, setImageError] = useState(false);
  const [imageLoading, setImageLoading] = useState(true);

  // Animation values
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);
  const heartScale = useSharedValue(1);

  // Reset image state when product changes
  React.useEffect(() => {
    setImageError(false);
    setImageLoading(true);
  }, [product.id]);

  const isInWishlist = wishlistItems.some(
    (item) => item.type === 'product' && item.itemId === product.id
  );

  // Animation styles
  const cardAnimatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  const heartAnimatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: heartScale.value }],
  }));

  // Animation handlers
  const handlePressIn = () => {
    scale.value = withSpring(0.95, { damping: 15, stiffness: 300 });
    opacity.value = withTiming(0.8, { duration: 100 });
  };

  const handlePressOut = () => {
    scale.value = withSpring(1, { damping: 15, stiffness: 300 });
    opacity.value = withTiming(1, { duration: 100 });
  };

  const handleAddToCart = (e: any) => {
    e.stopPropagation();

    // Check stock availability
    if (!product.inStock || product.stockQuantity <= 0) {
      // Could add a toast/snackbar here for "Out of stock" message
      return;
    }

    dispatch(addToCart({ product, quantity: 1 }));
  };

  const handleBuyNow = (e: any) => {
    e.stopPropagation();

    if (!product.inStock || product.stockQuantity <= 0) {
      return;
    }

    const buyNowLine = { product, quantity: 1 };
    dispatch(setBuyNowItem(buyNowLine));
    navigation.dispatch(
      StackActions.push('CheckoutAddress', { flow: 'buy_now', buyNowLine })
    );
  };

  const handleToggleWishlist = (e: any) => {
    e.stopPropagation();

    // Heart animation
    heartScale.value = withSpring(1.3, { damping: 10, stiffness: 400 }, () => {
      heartScale.value = withSpring(1, { damping: 15, stiffness: 300 });
    });

    if (isInWishlist) {
      const wishlistItem = wishlistItems.find(
        (item) => item.type === 'product' && item.itemId === product.id
      );
      if (wishlistItem) {
        dispatch(removeFromWishlist(wishlistItem.id));
      }
    } else {
      dispatch(addToWishlist({ type: 'product', item: product }));
    }
  };

  // Better image URL handling with multiple fallbacks
  const getImageUrl = () => {
    const primaryImage = product.thumbnail?.url || product.images?.[0]?.url;
    if (primaryImage) {
      return fixImageUrl(primaryImage);
    }
    return 'https://images.unsplash.com/photo-1594322436404-5a0526db4d13?w=400&h=400&fit=crop';
  };

  const imageUrl = getImageUrl();

  // Calculate discount percentage (mock data for now)
  const originalPrice = product.price * 1.2; // Simulate 20% discount
  const discountPercentage = Math.round(((originalPrice - product.price) / originalPrice) * 100);
  const hasDiscount = discountPercentage > 0;

  const handleImageLoad = () => {
    setImageLoading(false);
    console.log('Image loaded successfully:', imageUrl);
  };

  const handleImageError = (error: any) => {
    console.log('Image failed to load:', imageUrl, error.nativeEvent);
    setImageError(true);
    setImageLoading(false);
  };

  return (
    <AnimatedPressable
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      style={cardAnimatedStyle}
    >
      <AnimatedCard style={styles.card} mode="elevated">
        {/* Image */}
        <View style={styles.imageContainer}>
          {imageError ? (
            <View style={[styles.image, styles.imagePlaceholder]}>
              <MaterialCommunityIcons
                name="image-off"
                size={40}
                color={theme.colors.onSurfaceVariant}
              />
              <Text variant="bodySmall" style={styles.placeholderText}>
                No Image
              </Text>
            </View>
          ) : (
            <>
              <Image
                source={{ uri: imageUrl }}
                style={styles.image}
                resizeMode="cover"
                onLoad={handleImageLoad}
                onError={handleImageError}
              />
              {imageLoading && (
                <View style={[styles.image, styles.loadingOverlay]}>
                  <MaterialCommunityIcons
                    name="loading"
                    size={30}
                    color={theme.colors.primary}
                  />
                </View>
              )}
            </>
          )}

          {/* Stock Badge */}
          {!product.inStock && (
            <Badge style={styles.stockBadge} size={24}>
              Out of Stock
            </Badge>
          )}

          {/* Discount Badge */}
          {hasDiscount && (
            <View style={styles.discountBadge}>
              <Text style={styles.discountText}>{discountPercentage}% OFF</Text>
            </View>
          )}

          {/* Wishlist Button */}
          <Animated.View style={heartAnimatedStyle}>
            <IconButton
              icon={isInWishlist ? 'heart' : 'heart-outline'}
              iconColor={isInWishlist ? theme.colors.error : theme.colors.onSurface}
              size={24}
              style={styles.wishlistButton}
              onPress={handleToggleWishlist}
            />
          </Animated.View>
        </View>

        {/* Content */}
        <Card.Content style={styles.content}>
          {/* Category */}
          <Text variant="labelSmall" style={styles.category} numberOfLines={1}>
            {product.category.name}
          </Text>

          {/* Name */}
          <Text variant="titleMedium" style={styles.name} numberOfLines={2}>
            {product.name}
          </Text>

          {/* Rating */}
          <View style={styles.ratingContainer}>
            <MaterialCommunityIcons name="star" size={16} color="#FFC107" />
            <Text variant="bodySmall" style={styles.rating}>
              {product.rating.toFixed(1)} ({product.reviewCount})
            </Text>
          </View>

          {/* Price & Cart */}
          <View style={styles.footer}>
            <View style={styles.priceContainer}>
              {hasDiscount && (
                <Text variant="bodySmall" style={styles.originalPrice}>
                  {formatCurrency(originalPrice, product.currency)}
                </Text>
              )}
              <Text variant="titleLarge" style={[styles.price, { color: theme.colors.primary }]}>
                {formatCurrency(product.price, product.currency)}
              </Text>
              {hasDiscount && (
                <Text variant="bodySmall" style={styles.savings}>
                  You save ₹{Math.round(originalPrice - product.price)}
                </Text>
              )}
            </View>

            <View style={styles.actions}>
              <IconButton
                icon="lightning-bolt"
                iconColor={theme.colors.onPrimary}
                size={20}
                mode="contained"
                containerColor="#FB641B" // Flipkart Orange
                onPress={handleBuyNow}
                disabled={!product.inStock}
                style={styles.actionButton}
              />
              <IconButton
                icon="cart-plus"
                iconColor={theme.colors.onPrimary}
                size={20}
                mode="contained"
                containerColor={product.inStock ? theme.colors.primary : theme.colors.surfaceDisabled}
                onPress={handleAddToCart}
                disabled={!product.inStock}
                style={styles.actionButton}
              />
            </View>
          </View>
        </Card.Content>
      </AnimatedCard>
    </AnimatedPressable>
  );
}

const styles = StyleSheet.create({
  card: {
    marginBottom: spacing.md,
    overflow: 'hidden',
    minHeight: 320, // Ensure consistent minimum height
  },
  imageContainer: {
    position: 'relative',
    width: '100%',
    height: 200,
    backgroundColor: '#F5F5F5',
  },
  image: {
    width: '100%',
    height: '100%',
  },
  stockBadge: {
    position: 'absolute',
    top: spacing.sm,
    left: spacing.sm,
    backgroundColor: '#F44336',
  },
  wishlistButton: {
    position: 'absolute',
    top: 0,
    right: 0,
    margin: 0,
  },
  content: {
    paddingVertical: spacing.sm,
  },
  category: {
    opacity: 0.6,
    marginBottom: spacing.xs,
    textTransform: 'uppercase',
  },
  name: {
    marginBottom: spacing.xs,
    fontWeight: '700', // Increased form 600
    fontSize: 16,
    lineHeight: 22,
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  rating: {
    marginLeft: spacing.xs,
    opacity: 0.7,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.xs,
    gap: 8,
  },
  actions: {
    flexDirection: 'row',
    gap: 0,
  },
  actionButton: {
    margin: 0,
    marginHorizontal: 2,
  },
  price: {
    fontWeight: '800', // Increased from 700
    fontSize: 18,
  },
  imagePlaceholder: {
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
  },
  placeholderText: {
    marginTop: 8,
    opacity: 0.6,
  },
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.8)',
  },
  discountBadge: {
    position: 'absolute',
    top: spacing.sm,
    right: spacing.sm,
    backgroundColor: '#FF6B35',
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: 4,
  },
  discountText: {
    color: 'white',
    fontSize: 10,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  priceContainer: {
    flex: 1,
  },
  originalPrice: {
    textDecorationLine: 'line-through',
    opacity: 0.6,
    fontSize: 12,
  },
  savings: {
    color: '#4CAF50',
    fontSize: 10,
    fontWeight: '500',
  },
});
