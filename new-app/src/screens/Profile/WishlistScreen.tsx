import React from 'react';
import { View, StyleSheet, FlatList } from 'react-native';
import { Appbar, Card, Text, IconButton, useTheme, Chip } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { removeFromWishlist } from '@/store/slices/wishlistSlice';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import EmptyState from '@/components/common/EmptyState';

export default function WishlistScreen() {
  const navigation = useNavigation();
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const wishlistItems = useAppSelector((state) => state.wishlist.items);

  const handleRemoveFromWishlist = (itemId: string) => {
    dispatch(removeFromWishlist(itemId));
  };

  const handleItemPress = (item: any) => {
    const { type, item: data } = item;

    if (type === 'product') {
      (navigation as any).navigate('ProductDetail', { productId: data.id });
    } else if (type === 'book') {
      (navigation as any).navigate('BookDetail', { bookId: data.id });
    } else if (type === 'video') {
      (navigation as any).navigate('VideoDetail', { videoId: data.id });
    } else if (type === 'music') {
      (navigation as any).navigate('MusicDetail', { musicId: data.id });
    }
  };

  const renderItem = ({ item }: { item: any }) => {
    const { type, item: data, id } = item;

    const getImageUrl = (item: any) => {
      const imageUrl = item.images?.[0]?.url || item.image || item.coverImage || item.thumbnailUrl;
      if (!imageUrl) return 'https://via.placeholder.com/100';
      return fixImageUrl(imageUrl);
    };

    return (
      <Card style={styles.card} onPress={() => handleItemPress(item)}>
        <Card.Cover
          source={{
            uri: getImageUrl(data)
          }}
          style={styles.cardCover}
        />
        <Card.Content style={styles.cardContent}>
          <View style={styles.cardHeader}>
            <Chip mode="outlined" compact style={styles.typeChip}>
              {type}
            </Chip>
            <IconButton
              icon="heart"
              iconColor={theme.colors.error}
              size={20}
              onPress={() => handleRemoveFromWishlist(id)}
              style={styles.removeButton}
            />
          </View>

          <Text variant="titleMedium" numberOfLines={2} style={styles.itemName}>
            {data.name}
          </Text>

          <Text variant="bodyMedium" style={styles.category}>
            {data.category?.name || data.category}
          </Text>

          <Text variant="titleSmall" style={[styles.price, { color: theme.colors.primary }]}>
            {formatCurrency(data.price, data.currency)}
          </Text>
        </Card.Content>
      </Card>
    );
  };

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.Content title="My Wishlist" />
      </Appbar.Header>

      {wishlistItems.length === 0 ? (
        <EmptyState
          icon="heart-outline"
          title="No items in wishlist"
          message="Save your favorite items to see them here."
        />
      ) : (
        <View style={styles.content}>
          <Text variant="titleMedium" style={styles.itemCount}>
            {wishlistItems.length} {wishlistItems.length === 1 ? 'item' : 'items'} saved
          </Text>
          <FlatList
            data={wishlistItems}
            renderItem={renderItem}
            keyExtractor={(item) => item.id}
            numColumns={2}
            contentContainerStyle={styles.listContent}
            columnWrapperStyle={styles.row}
            showsVerticalScrollIndicator={false}
          />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1
  },
  content: {
    flex: 1,
  },
  itemCount: {
    padding: spacing.md,
    paddingBottom: spacing.sm,
    opacity: 0.7,
  },
  listContent: {
    padding: spacing.md,
  },
  row: {
    justifyContent: 'space-between',
  },
  card: {
    flex: 1,
    maxWidth: '48%',
    marginBottom: spacing.md,
  },
  cardCover: {
    height: 150,
  },
  cardContent: {
    paddingTop: spacing.sm,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  typeChip: {
    height: 24,
  },
  removeButton: {
    margin: 0,
  },
  itemName: {
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  category: {
    opacity: 0.7,
    marginBottom: spacing.xs,
  },
  price: {
    fontWeight: 'bold',
  },
});
