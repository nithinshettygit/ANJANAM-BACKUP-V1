import React, { useRef, useEffect, useState } from 'react';
import {
  View,
  StyleSheet,
  Dimensions,
  Image,
  TouchableOpacity,
  FlatList,
} from 'react-native';
import { Text, useTheme } from 'react-native-paper';
import { spacing, componentShadows, shadows, gradients, typography, sanctuaryColors } from '@/theme';

const { width: screenWidth } = Dimensions.get('window');
const BANNER_WIDTH = screenWidth - spacing.lg * 2;
const BANNER_HEIGHT = 220;

interface Banner {
  id: string;
  image: string;
  title: string;
  subtitle: string;
  action: () => void;
}

interface BannerCarouselProps {
  banners: Banner[];
}

export default function BannerCarousel({ banners }: BannerCarouselProps) {
  const theme = useTheme();
  const flatListRef = useRef<FlatList>(null);
  const [currentIndex, setCurrentIndex] = useState(0);

  // Auto-scroll functionality
  useEffect(() => {
    if (banners.length <= 1) return;

    const interval = setInterval(() => {
      setCurrentIndex((prevIndex) => {
        const nextIndex = (prevIndex + 1) % banners.length;
        flatListRef.current?.scrollToIndex({
          index: nextIndex,
          animated: true,
        });
        return nextIndex;
      });
    }, 4000); // Auto-scroll every 4 seconds

    return () => clearInterval(interval);
  }, [banners.length]);

  const renderBanner = ({ item }: { item: Banner; index: number }) => {
    return (
      <View style={styles.bannerContainer}>
        <TouchableOpacity
          style={styles.banner}
          onPress={item.action}
          activeOpacity={0.9}
        >
          <Image source={{ uri: item.image }} style={styles.bannerImage} />
          <View style={styles.bannerOverlay}>
            <View style={styles.bannerContent}>
              <Text style={styles.bannerTitle}>
                {item.title}
              </Text>
              <Text style={styles.bannerSubtitle}>
                {item.subtitle}
              </Text>
            </View>
          </View>
        </TouchableOpacity>
      </View>
    );
  };

  const renderDot = (index: number) => {
    return (
      <View
        key={index}
        style={[
          styles.dot,
          {
            backgroundColor: currentIndex === index ? sanctuaryColors.deepGold : sanctuaryColors.mildBeige,
            opacity: currentIndex === index ? 1 : 0.6,
            transform: [{ scale: currentIndex === index ? 1.2 : 1 }],
          },
        ]}
      />
    );
  };

  const onMomentumScrollEnd = (event: any) => {
    const newIndex = Math.round(event.nativeEvent.contentOffset.x / BANNER_WIDTH);
    setCurrentIndex(newIndex);
  };

  const styles = createStyles();

  return (
    <View style={styles.container}>
      <FlatList
        ref={flatListRef}
        data={banners}
        renderItem={renderBanner}
        keyExtractor={(item) => item.id}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={onMomentumScrollEnd}
        snapToInterval={BANNER_WIDTH}
        decelerationRate="fast"
        contentContainerStyle={styles.flatListContent}
      />
      
      {/* Pagination Dots */}
      <View style={styles.pagination}>
        {banners.map((_, index) => renderDot(index))}
      </View>
    </View>
  );
}

const createStyles = () => StyleSheet.create({
  container: {
    marginVertical: spacing.md,
  },
  flatListContent: {
    paddingHorizontal: spacing.lg,
  },
  bannerContainer: {
    width: BANNER_WIDTH,
    marginHorizontal: spacing.xs,
  },
  banner: {
    height: BANNER_HEIGHT,
    borderRadius: 16,
    overflow: 'hidden',
    ...componentShadows.card,
  },
  bannerImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  bannerOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '60%',
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(27, 27, 27, 0.7)',
  },
  bannerContent: {
    padding: spacing.lg,
  },
  bannerTitle: {
    ...typography.h3,
    color: sanctuaryColors.deepGold,
    marginBottom: spacing.xs,
    textShadowColor: 'rgba(0, 0, 0, 0.8)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 3,
  },
  bannerSubtitle: {
    ...typography.bodyMedium,
    color: '#FFFFFF',
    opacity: 0.95,
    textShadowColor: 'rgba(0, 0, 0, 0.6)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 2,
  },
  pagination: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: spacing.md,
    gap: spacing.xs,
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    ...shadows.gentle,
  },
});
