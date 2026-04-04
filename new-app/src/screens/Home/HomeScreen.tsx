import React, { useState, useEffect } from 'react';
import {
  View,
  StyleSheet,
  ScrollView,
  RefreshControl,
  Image,
} from 'react-native';
import { Appbar, Text, useTheme } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { CompositeNavigationProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { useQuery } from '@apollo/client';
import { RootStackParamList, BottomTabParamList } from '@/types';
import { GET_PRODUCTS } from '@/graphql/queries/products';
import { API_CONFIG, APP_LOGO } from '@/constants';
import { spacing, sanctuaryColors, typography, gradients } from '@/theme';
import { useAppSelector } from '@/hooks/useTypedSelector';

// Import components
import {
  BannerCarousel,
  SectionButtons,
  ProductCarousel,
  ShimmerLoader,
} from './components';

type NavigationProp = CompositeNavigationProp<
  BottomTabNavigationProp<BottomTabParamList>,
  StackNavigationProp<RootStackParamList>
>;

export default function HomeScreen() {
  const navigation = useNavigation<NavigationProp>();
  const theme = useTheme();
  const cartItems = useAppSelector((state) => state.cart.cart.items);

  const [refreshing, setRefreshing] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  // Animation values
  const fadeAnim = useSharedValue(0);
  const slideAnim = useSharedValue(50);

  // Fetch products data from Saleor backend
  const { data, loading, error, refetch } = useQuery(GET_PRODUCTS, {
    variables: {
      first: 50,
      channel: API_CONFIG.SALEOR_CHANNEL,
    },
    fetchPolicy: 'cache-and-network',
  });

  useEffect(() => {
    if (data) {
      setIsLoading(false);
      // Trigger entrance animations
      fadeAnim.value = withTiming(1, { duration: 800 });
      slideAnim.value = withSpring(0, { damping: 15, stiffness: 150 });
    }
  }, [data]);

  useEffect(() => {
    if (error) {
      console.error('GraphQL Error:', error);
      setIsLoading(false);
    }
  }, [error]);

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
        ...node.media?.map((m: any, idx: number) => ({ id: String(idx + 2), url: m.url, alt: node.name })) || [],
      ],
      category: {
        id: node.category?.id || 'unc',
        name: node.category?.name || 'Uncategorized',
        slug: node.category?.slug || 'uncategorized',
      },
      rating: 4.5,
      reviewCount: Math.floor(Math.random() * 100) + 10,
      inStock,
      stockQuantity,
      slug: node.id,
      createdAt: node.created || new Date().toISOString(),
      attributes: [],
      variants: [],
    };
  }) || [];

  // Sample banner data
  const banners = [
    {
      id: '1',
      image: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=400&fit=crop',
      title: 'New Arrivals',
      subtitle: 'Discover the latest products',
      action: () => navigation.navigate('Shop'),
    },
    {
      id: '2',
      image: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=400&fit=crop',
      title: 'Best Books',
      subtitle: 'Expand your knowledge',
      action: () => navigation.navigate('Books'),
    },
    {
      id: '3',
      image: 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=800&h=400&fit=crop',
      title: 'Music Collection',
      subtitle: 'Feel the rhythm',
      action: () => navigation.navigate('Music'),
    },
  ];

  // Create smart recommendations from Saleor data
  const sortedByCreatedAt = [...products].sort((a: any, b: any) => {
    const aTime = a?.createdAt ? new Date(a.createdAt).getTime() : 0;
    const bTime = b?.createdAt ? new Date(b.createdAt).getTime() : 0;
    return bTime - aTime;
  });

  const recentProducts = sortedByCreatedAt.slice(0, 10);

  // Trending: Products with higher ratings or specific categories
  const trendingProducts = products
    .filter((p: any) => p.rating >= 4.0 || ['meditation', 'yoga', 'wellness'].includes(p.category.slug))
    .slice(0, 10);

  // Recommended: Mix of different categories for variety
  const recommendedProducts = products
    .sort((a: any, b: any) => {
      // Prioritize products with images and good ratings
      const aScore = (a.images.length > 0 ? 1 : 0) + (a.rating >= 4.0 ? 1 : 0);
      const bScore = (b.images.length > 0 ? 1 : 0) + (b.rating >= 4.0 ? 1 : 0);
      return bScore - aScore;
    })
    .slice(0, 10);

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await refetch();
    } finally {
      setRefreshing(false);
    }
  };

  const handleCartPress = () => {
    navigation.navigate('Cart');
  };

  const handleProfilePress = () => {
    navigation.navigate('Profile');
  };

  const handleProductPress = (productId: string) => {
    navigation.navigate('ProductDetail', { productId });
  };

  const handleSearchPress = () => {
    navigation.navigate('Search', { initialQuery: '' });
  };

  // Animated styles
  const animatedContainerStyle = useAnimatedStyle(() => ({
    opacity: fadeAnim.value,
    transform: [{ translateY: slideAnim.value }],
  }));

  const styles = createStyles();

  if (isLoading && !data) {
    return (
      <View style={styles.container}>
        <Appbar.Header style={styles.header}>
          <Appbar.Content
            title={
              <View style={styles.headerBrand}>
                <Image
                  source={APP_LOGO}
                  style={styles.headerLogo}
                  resizeMode="contain"
                  accessibilityLabel="ANJANAM"
                  accessible
                />
              </View>
            }
          />
          <Appbar.Action
            icon="magnify"
            iconColor={sanctuaryColors.deepGold}
            onPress={handleSearchPress}
          />
          <Appbar.Action
            icon="cart"
            iconColor={sanctuaryColors.deepGold}
            onPress={handleCartPress}
          />
          <Appbar.Action
            icon="account-circle"
            iconColor={sanctuaryColors.deepGold}
            onPress={handleProfilePress}
          />
          {cartItems.length > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{cartItems.length}</Text>
            </View>
          )}
        </Appbar.Header>
        <ShimmerLoader />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Appbar.Header style={styles.header}>
        <Appbar.Content
          title={
            <View style={styles.headerBrand}>
              <Image
                source={APP_LOGO}
                style={styles.headerLogo}
                resizeMode="contain"
                accessibilityLabel="ANJANAM"
                accessible
              />
            </View>
          }
        />
        <Appbar.Action icon="magnify" iconColor={sanctuaryColors.deepGold} onPress={handleSearchPress} />
        <Appbar.Action icon="cart" iconColor={sanctuaryColors.deepGold} onPress={handleCartPress} />
        <Appbar.Action icon="account-circle" iconColor={sanctuaryColors.deepGold} onPress={handleProfilePress} />
        {cartItems.length > 0 && (
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{cartItems.length}</Text>
          </View>
        )}
      </Appbar.Header>

      <Animated.View style={[styles.content, animatedContainerStyle]}>
        <ScrollView
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={handleRefresh}
              colors={[theme.colors.primary]}
              tintColor={theme.colors.primary}
            />
          }
        >
          {/* Banner Carousel */}
          <BannerCarousel banners={banners} />

          {/* Section Navigation Buttons */}
          <SectionButtons navigation={navigation} />

          {/* Recent Products */}
          {recentProducts.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>
                Recently Added
              </Text>
              <ProductCarousel
                products={recentProducts}
                onProductPress={handleProductPress}
              />
            </View>
          )}

          {/* Trending Products */}
          {trendingProducts.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>
                Trending Now
              </Text>
              <ProductCarousel
                products={trendingProducts}
                onProductPress={handleProductPress}
              />
            </View>
          )}

          {/* Recommended Products */}
          {recommendedProducts.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>
                Recommended for You
              </Text>
              <ProductCarousel
                products={recommendedProducts}
                onProductPress={handleProductPress}
              />
            </View>
          )}

          {/* Bottom spacing */}
          <View style={styles.bottomSpacing} />
        </ScrollView>
      </Animated.View>
    </View>
  );
}

const createStyles = () =>
  StyleSheet.create({
    container: {
      flex: 1,
      backgroundColor: sanctuaryColors.lotusWhite,
    },
    header: {
      backgroundColor: sanctuaryColors.sandalwoodBeige,
      elevation: 0,
      shadowOpacity: 0,
    },
    content: {
      flex: 1,
    },
    headerBrand: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'flex-start',
      paddingVertical: 2,
    },
    headerLogo: {
      height: 40,
      width: 40,
    },
    badge: {
      position: 'absolute',
      top: 8,
      right: 56,
      backgroundColor: sanctuaryColors.errorRed,
      borderRadius: 10,
      minWidth: 20,
      height: 20,
      justifyContent: 'center',
      alignItems: 'center',
    },
    badgeText: {
      ...typography.caption,
      color: '#FFFFFF',
      fontSize: 12,
    },
    section: {
      marginVertical: spacing.md,
    },
    sectionTitle: {
      ...typography.h5,
      marginHorizontal: spacing.lg,
      marginBottom: spacing.md,
      color: sanctuaryColors.charcoalBlack,
    },
    bottomSpacing: {
      height: spacing.xl,
    },
  });
