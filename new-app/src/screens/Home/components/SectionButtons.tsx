import React from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Dimensions,
} from 'react-native';
import { Text, useTheme } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { CompositeNavigationProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { spacing, componentShadows, typography, sanctuaryColors } from '@/theme';
import { RootStackParamList, BottomTabParamList } from '@/types';

const { width: screenWidth } = Dimensions.get('window');

interface SectionButton {
  id: string;
  title: string;
  icon: keyof typeof MaterialCommunityIcons.glyphMap;
  color: string;
  action: () => void;
}

type NavigationProp = CompositeNavigationProp<
  BottomTabNavigationProp<BottomTabParamList>,
  StackNavigationProp<RootStackParamList>
>;

interface SectionButtonsProps {
  navigation: NavigationProp;
}

const AnimatedTouchableOpacity = Animated.createAnimatedComponent(TouchableOpacity);

export default function SectionButtons({ navigation }: SectionButtonsProps) {
  const theme = useTheme();

  const sections: SectionButton[] = [
    {
      id: 'shop',
      title: 'Shop',
      icon: 'shopping',
      color: sanctuaryColors.deepGold,
      action: () => navigation.navigate('Shop'),
    },
    {
      id: 'books',
      title: 'Books',
      icon: 'book-open-variant',
      color: sanctuaryColors.royalBlue,
      action: () => navigation.navigate('Books'),
    },
    {
      id: 'videos',
      title: 'Videos',
      icon: 'play-circle',
      color: sanctuaryColors.deepGold,
      action: () => navigation.navigate('Videos'),
    },
    {
      id: 'music',
      title: 'Music',
      icon: 'music',
      color: sanctuaryColors.sageGreen,
      action: () => navigation.navigate('Music'),
    },
    {
      id: 'cart',
      title: 'Cart',
      icon: 'cart',
      color: sanctuaryColors.marigoldOrange,
      action: () => navigation.navigate('Cart'),
    },
    {
      id: 'wishlist',
      title: 'Wishlist',
      icon: 'heart',
      color: sanctuaryColors.errorRed,
      action: () => navigation.navigate('Wishlist'),
    },
  ];

  const SectionButtonItem = ({ item }: { item: SectionButton }) => {
    const scale = useSharedValue(1);
    const opacity = useSharedValue(1);

    const animatedStyle = useAnimatedStyle(() => ({
      transform: [{ scale: scale.value }],
      opacity: opacity.value,
    }));

    const handlePressIn = () => {
      scale.value = withSpring(0.95, { damping: 15, stiffness: 300 });
      opacity.value = withTiming(0.8, { duration: 100 });
    };

    const handlePressOut = () => {
      scale.value = withSpring(1, { damping: 15, stiffness: 300 });
      opacity.value = withTiming(1, { duration: 100 });
    };

    const handlePress = () => {
      // Add haptic feedback effect
      scale.value = withSpring(0.9, { damping: 10, stiffness: 400 }, () => {
        scale.value = withSpring(1, { damping: 15, stiffness: 300 });
      });
      
      // Execute navigation after a short delay for better UX
      setTimeout(() => {
        item.action();
      }, 100);
    };

    return (
      <AnimatedTouchableOpacity
        style={[styles.sectionButton, animatedStyle]}
        onPress={handlePress}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        activeOpacity={1}
      >
        <View style={[styles.iconContainer, { backgroundColor: item.color }]}>
          <MaterialCommunityIcons
            name={item.icon}
            size={28}
            color="#fff"
          />
        </View>
        <Text style={styles.buttonText}>
          {item.title}
        </Text>
      </AnimatedTouchableOpacity>
    );
  };

  const styles = createStyles();

  return (
    <View style={styles.container}>
      <Text style={styles.sectionTitle}>
        Explore
      </Text>
      <View style={styles.buttonsGrid}>
        {sections.map((section) => (
          <SectionButtonItem key={section.id} item={section} />
        ))}
      </View>
    </View>
  );
}

const createStyles = () => StyleSheet.create({
  container: {
    marginVertical: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  sectionTitle: {
    ...typography.h4,
    marginBottom: spacing.md,
    color: sanctuaryColors.charcoalBlack,
  },
  buttonsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    gap: spacing.md,
  },
  sectionButton: {
    width: (screenWidth - spacing.lg * 2 - spacing.md * 2) / 3,
    alignItems: 'center',
    paddingVertical: spacing.md,
  },
  iconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.sm,
    ...componentShadows.button,
  },
  buttonText: {
    ...typography.caption,
    textAlign: 'center',
    color: sanctuaryColors.charcoalBlack,
    marginTop: spacing.xs,
  },
});
