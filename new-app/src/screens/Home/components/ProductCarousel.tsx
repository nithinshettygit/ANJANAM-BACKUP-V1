import React, { useState } from 'react';
import {
  View,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Image,
  Dimensions,
} from 'react-native';
import { Text, Card, useTheme, Badge } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { fixImageUrl } from '@/utils/url';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { spacing, componentShadows, shadows, typography, sanctuaryColors } from '@/theme';
import { Product } from '@/types';
import { formatCurrency } from '@/utils/format';

const { width: screenWidth } = Dimensions.get('window');
const CARD_WIDTH = 160;
const CARD_HEIGHT = 220;

interface ProductCarouselProps {
  products: Product[];
  onProductPress: (productId: string) => void;
}

const AnimatedTouchableOpacity = Animated.createAnimatedComponent(TouchableOpacity);

export default function ProductCarousel({ products, onProductPress }: ProductCarouselProps) {
  const theme = useTheme();

  const ProductCard = ({ product }: { product: Product }) => {
    const scale = useSharedValue(1);
    const shadowOpacity = useSharedValue(0.1);
    const [imageError, setImageError] = useState(false);
    const [imageLoading, setImageLoading] = useState(true);

    const animatedStyle = useAnimatedStyle(() => ({
      transform: [{ scale: scale.value }],
    }));

    const shadowStyle = useAnimatedStyle(() => ({
      shadowOpacity: shadowOpacity.value,
      elevation: shadowOpacity.value * 10,
    }));

    const handlePressIn = () => {
      scale.value = withSpring(0.95, { damping: 15, stiffness: 300 });
      shadowOpacity.value = withTiming(0.2, { duration: 150 });
    };

    const handlePressOut = () => {
      scale.value = withSpring(1, { damping: 15, stiffness: 300 });
      shadowOpacity.value = withTiming(0.1, { duration: 150 });
    };

    const handlePress = () => {
      // Add bounce effect
      scale.value = withSpring(0.9, { damping: 10, stiffness: 400 }, () => {
        scale.value = withSpring(1, { damping: 15, stiffness: 300 });
      });

      setTimeout(() => {
        onProductPress(product.id);
      }, 100);
    };

    const handleImageLoad = () => {
      setImageLoading(false);
    };

    const handleImageError = () => {
      setImageError(true);
      setImageLoading(false);
    };

    const getImageUrl = () => {
      const primaryImage = product.thumbnail?.url || product.images?.[0]?.url;
      if (primaryImage) {
        return fixImageUrl(primaryImage);
      }
      return 'https://via.placeholder.com/200';
    };

    const imageUrl = getImageUrl();

    return (
      <AnimatedTouchableOpacity
        style={[styles.cardContainer, animatedStyle]}
        onPress={handlePress}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        activeOpacity={1}
      >
        <Animated.View style={[styles.card, shadowStyle]}>
          <View style={styles.imageContainer}>
            {imageError ? (
              <View style={[styles.productImage, styles.imagePlaceholder]}>
                <MaterialCommunityIcons
                  name="image-off"
                  size={24}
                  color={theme.colors.onSurfaceVariant}
                />
              </View>
            ) : (
              <>
                <Image
                  source={{ uri: imageUrl }}
                  style={styles.productImage}
                  resizeMode="cover"
                  onLoad={handleImageLoad}
                  onError={handleImageError}
                />
                {imageLoading && (
                  <View style={[styles.productImage, styles.loadingOverlay]}>
                    <MaterialCommunityIcons
                      name="loading"
                      size={20}
                      color={theme.colors.primary}
                    />
                  </View>
                )}
              </>
            )}
            {/* Rating Badge */}
            <View style={styles.ratingBadge}>
              <MaterialCommunityIcons name="star" size={12} color="#FFD700" />
              <Text style={styles.ratingText}>{product.rating.toFixed(1)}</Text>
            </View>
          </View>

          <View style={styles.cardContent}>
            <Text
              style={styles.productName}
              numberOfLines={2}
            >
              {product.name}
            </Text>

            <View style={styles.priceContainer}>
              <Text style={styles.price}>
                {formatCurrency(product.price, product.currency)}
              </Text>
              {product.reviewCount > 0 && (
                <Text style={styles.reviews}>
                  ({product.reviewCount})
                </Text>
              )}
            </View>

            {/* Category Tag */}
            <View style={styles.categoryTag}>
              <Text style={styles.categoryText}>
                {product.category.name}
              </Text>
            </View>
          </View>
        </Animated.View>
      </AnimatedTouchableOpacity>
    );
  };

  const renderProduct = ({ item }: { item: Product }) => (
    <ProductCard product={item} />
  );

  const styles = createStyles();

  return (
    <View style={styles.container}>
      <FlatList
        data={products}
        renderItem={renderProduct}
        keyExtractor={(item) => item.id}
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        snapToInterval={CARD_WIDTH + spacing.md}
        decelerationRate="fast"
        scrollEventThrottle={16}
      />
    </View>
  );
}

const createStyles = () => StyleSheet.create({
  container: {
    marginVertical: spacing.xs,
  },
  listContent: {
    paddingHorizontal: spacing.lg,
    gap: spacing.md,
  },
  cardContainer: {
    width: CARD_WIDTH,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    overflow: 'hidden',
    height: CARD_HEIGHT,
    borderWidth: 1,
    borderColor: sanctuaryColors.mildBeige,
    ...componentShadows.card,
  },
  imageContainer: {
    position: 'relative',
    height: 120,
  },
  productImage: {
    width: '100%',
    height: '100%',
  },
  ratingBadge: {
    position: 'absolute',
    top: spacing.sm,
    right: spacing.sm,
    backgroundColor: sanctuaryColors.deepGold,
    borderRadius: 12,
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    ...shadows.gentle,
  },
  ratingText: {
    ...typography.caption,
    color: '#FFFFFF',
    fontSize: 10,
  },
  cardContent: {
    padding: spacing.sm,
    flex: 1,
    justifyContent: 'space-between',
  },
  productName: {
    ...typography.bodySmall,
    fontWeight: '600',
    color: sanctuaryColors.charcoalBlack,
    lineHeight: 18,
  },
  priceContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: spacing.xs,
  },
  price: {
    ...typography.price,
    color: sanctuaryColors.deepGold,
  },
  reviews: {
    ...typography.caption,
    color: sanctuaryColors.warmGray,
    fontSize: 10,
  },
  categoryTag: {
    backgroundColor: sanctuaryColors.lightBeige,
    borderRadius: 8,
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    alignSelf: 'flex-start',
    marginTop: spacing.xs,
    borderWidth: 1,
    borderColor: sanctuaryColors.mildBeige,
  },
  categoryText: {
    ...typography.caption,
    color: sanctuaryColors.sageGreen,
    fontSize: 10,
  },
  imagePlaceholder: {
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: sanctuaryColors.lightBeige,
  },
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.8)',
  },
});
