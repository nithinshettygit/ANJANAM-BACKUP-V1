import React, { useEffect } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { useTheme } from 'react-native-paper';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { spacing } from '@/theme';

const { width: screenWidth } = Dimensions.get('window');

export default function ShimmerLoader() {
  const theme = useTheme();
  const shimmerAnimation = useSharedValue(0);

  useEffect(() => {
    shimmerAnimation.value = withRepeat(
      withTiming(1, { duration: 1500 }),
      -1,
      false
    );
  }, []);

  const createShimmerStyle = (width: number, height: number) => {
    return useAnimatedStyle(() => {
      const opacity = interpolate(
        shimmerAnimation.value,
        [0, 0.5, 1],
        [0.3, 0.7, 0.3]
      );
      
      return {
        width,
        height,
        backgroundColor: theme.colors.surfaceVariant,
        opacity,
      };
    });
  };

  const styles = createStyles(theme);

  return (
    <View style={styles.container}>
      {/* Banner Shimmer */}
      <View style={styles.bannerContainer}>
        <Animated.View
          style={[
            styles.shimmerItem,
            styles.banner,
            createShimmerStyle(screenWidth - spacing.lg * 2, 200),
          ]}
        />
      </View>

      {/* Section Buttons Shimmer */}
      <View style={styles.sectionContainer}>
        <Animated.View
          style={[
            styles.shimmerItem,
            styles.sectionTitle,
            createShimmerStyle(120, 24),
          ]}
        />
        <View style={styles.buttonsGrid}>
          {Array.from({ length: 6 }).map((_, index) => (
            <View key={index} style={styles.buttonContainer}>
              <Animated.View
                style={[
                  styles.shimmerItem,
                  styles.buttonIcon,
                  createShimmerStyle(60, 60),
                ]}
              />
              <Animated.View
                style={[
                  styles.shimmerItem,
                  styles.buttonText,
                  createShimmerStyle(50, 16),
                ]}
              />
            </View>
          ))}
        </View>
      </View>

      {/* Product Carousels Shimmer */}
      {Array.from({ length: 3 }).map((_, sectionIndex) => (
        <View key={sectionIndex} style={styles.carouselSection}>
          <Animated.View
            style={[
              styles.shimmerItem,
              styles.carouselTitle,
              createShimmerStyle(150, 24),
            ]}
          />
          <View style={styles.carouselContainer}>
            {Array.from({ length: 3 }).map((_, cardIndex) => (
              <View key={cardIndex} style={styles.productCard}>
                <Animated.View
                  style={[
                    styles.shimmerItem,
                    styles.productImage,
                    createShimmerStyle(160, 120),
                  ]}
                />
                <View style={styles.productInfo}>
                  <Animated.View
                    style={[
                      styles.shimmerItem,
                      styles.productName,
                      createShimmerStyle(140, 16),
                    ]}
                  />
                  <Animated.View
                    style={[
                      styles.shimmerItem,
                      styles.productPrice,
                      createShimmerStyle(80, 14),
                    ]}
                  />
                  <Animated.View
                    style={[
                      styles.shimmerItem,
                      styles.productCategory,
                      createShimmerStyle(60, 12),
                    ]}
                  />
                </View>
              </View>
            ))}
          </View>
        </View>
      ))}
    </View>
  );
}

const createStyles = (theme: any) => StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  shimmerItem: {
    borderRadius: 8,
  },
  bannerContainer: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  banner: {
    borderRadius: 16,
  },
  sectionContainer: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  sectionTitle: {
    marginBottom: spacing.md,
  },
  buttonsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    gap: spacing.md,
  },
  buttonContainer: {
    width: (screenWidth - spacing.lg * 2 - spacing.md * 2) / 3,
    alignItems: 'center',
  },
  buttonIcon: {
    borderRadius: 30,
    marginBottom: spacing.sm,
  },
  buttonText: {
    borderRadius: 4,
  },
  carouselSection: {
    paddingVertical: spacing.md,
  },
  carouselTitle: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.md,
  },
  carouselContainer: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
    gap: spacing.md,
  },
  productCard: {
    width: 160,
    backgroundColor: theme.colors.surface,
    borderRadius: 12,
    overflow: 'hidden',
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
  },
  productImage: {
    borderTopLeftRadius: 12,
    borderTopRightRadius: 12,
  },
  productInfo: {
    padding: spacing.sm,
    gap: spacing.xs,
  },
  productName: {
    borderRadius: 4,
  },
  productPrice: {
    borderRadius: 4,
  },
  productCategory: {
    borderRadius: 6,
  },
});
