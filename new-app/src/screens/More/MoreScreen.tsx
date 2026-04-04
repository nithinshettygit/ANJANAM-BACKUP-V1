import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { Text } from 'react-native-paper';
import { useNavigation, CompositeNavigationProp } from '@react-navigation/native';
import { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import { StackNavigationProp } from '@react-navigation/stack';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { RootStackParamList, BottomTabParamList } from '@/types';
import { spacing, sanctuaryColors, typography, componentShadows } from '@/theme';

type NavigationProp = CompositeNavigationProp<
  BottomTabNavigationProp<BottomTabParamList>,
  StackNavigationProp<RootStackParamList>
>;

export default function MoreScreen() {
  const navigation = useNavigation<NavigationProp>();

  const options = [
    {
      id: 'videos',
      title: 'Videos',
      icon: 'play-circle' as const,
      color: sanctuaryColors.deepGold,
      action: () => navigation.navigate('Videos' as never),
    },
    {
      id: 'music',
      title: 'Music',
      icon: 'music' as const,
      color: sanctuaryColors.sageGreen,
      action: () => navigation.navigate('Music' as never),
    },
  ];

  return (
    <View style={styles.container}>
      <Text style={styles.title}>More</Text>
      <Text style={styles.subtitle}>Explore spiritual content</Text>
      <View style={styles.grid}>
        {options.map((item) => (
          <TouchableOpacity
            key={item.id}
            style={styles.card}
            activeOpacity={0.9}
            onPress={item.action}
          >
            <View style={[styles.iconContainer, { backgroundColor: item.color }]}>
              <MaterialCommunityIcons name={item.icon} size={32} color="#FFFFFF" />
            </View>
            <Text style={styles.cardTitle}>{item.title}</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
    backgroundColor: sanctuaryColors.lotusWhite,
  },
  title: {
    ...typography.h3,
    color: sanctuaryColors.charcoalBlack,
    marginBottom: spacing.xs,
  },
  subtitle: {
    ...typography.bodyMedium,
    color: sanctuaryColors.warmGray,
    marginBottom: spacing.lg,
  },
  grid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: spacing.lg,
  },
  card: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.lg,
    borderRadius: 16,
    backgroundColor: '#FFFFFF',
    ...componentShadows.card,
  },
  iconContainer: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.md,
  },
  cardTitle: {
    ...typography.bodyMedium,
    color: sanctuaryColors.charcoalBlack,
  },
});
