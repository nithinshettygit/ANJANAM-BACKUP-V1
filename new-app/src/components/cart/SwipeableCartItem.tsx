import React from 'react';
import { View, StyleSheet, Image, TouchableOpacity, Alert, Platform } from 'react-native';
import { fixImageUrl } from '@/utils/url';
import { Card, Text, IconButton, Button, useTheme, Snackbar } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Swipeable } from 'react-native-gesture-handler';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { useRef } from 'react';
import { StackActions, useNavigation } from '@react-navigation/native';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import { useAppDispatch } from '@/hooks/useTypedSelector';
import { setBuyNowItem } from '@/store/slices/buyNowSlice';
import { CartItem } from '@/types';



interface SwipeableCartItemProps {
  item: CartItem;
  onRemove: (itemId: string) => void;
  onUpdateQuantity: (itemId: string, delta: number) => void;
  onPress: (item: CartItem) => void;
}

const AnimatedCard = Animated.createAnimatedComponent(Card);

export default function SwipeableCartItem({
  item,
  onRemove,
  onUpdateQuantity,
  onPress,
}: SwipeableCartItemProps) {
  const theme = useTheme();
  const navigation = useNavigation<any>();
  const dispatch = useAppDispatch();
  const swipeableRef = useRef<Swipeable>(null);
  const scale = useSharedValue(1);
  const [snackbarVisible, setSnackbarVisible] = React.useState(false);
  const [snackbarMessage, setSnackbarMessage] = React.useState('');

  // Animation for item interactions
  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = () => {
    scale.value = withSpring(0.98, { damping: 15, stiffness: 300 });
  };

  const handlePressOut = () => {
    scale.value = withSpring(1, { damping: 15, stiffness: 300 });
  };

  // Get available stock for this item
  const availableStock = item.variant?.stockQuantity ?? item.product.stockQuantity;
  const isInStock = item.product.inStock && availableStock > 0;
  const maxQuantity = Math.min(10, availableStock); // Max 10 or available stock

  const showSnackbar = (message: string) => {
    setSnackbarMessage(message);
    setSnackbarVisible(true);
  };

  const handleQuantityChange = (delta: number) => {
    const newQuantity = item.quantity + delta;

    if (delta > 0) {
      // Increasing quantity
      if (newQuantity > maxQuantity) {
        if (availableStock <= item.quantity) {
          showSnackbar(`Only ${availableStock} items available in stock`);
        } else {
          showSnackbar(`Maximum ${maxQuantity} items allowed per order`);
        }
        return;
      }
      if (newQuantity > availableStock) {
        showSnackbar(`Only ${availableStock} items left in stock`);
        return;
      }
    } else {
      // Decreasing quantity
      if (newQuantity < 1) {
        showSnackbar('Minimum quantity is 1');
        return;
      }
    }

    onUpdateQuantity(item.id, delta);
  };

  const handleRemove = () => {
    Alert.alert(
      'Remove Item',
      `Are you sure you want to remove "${item.product.name}" from your cart?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: () => onRemove(item.id)
        },
      ]
    );
  };

  // Calculate delivery date (5-7 days from now)
  const deliveryDate = new Date();
  deliveryDate.setDate(deliveryDate.getDate() + 6);
  const deliveryDateString = deliveryDate.toLocaleDateString('en-IN', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });

  const handleBuyNow = () => {
    const buyNowLine = {
      product: item.product,
      variant: item.variant,
      quantity: item.quantity,
    };
    dispatch(setBuyNowItem(buyNowLine));

    // Push fresh screen + explicit line in params (avoids stale stack/Redux/persist edge cases).
    navigation.dispatch(
      StackActions.push('CheckoutAddress', {
        flow: 'buy_now',
        buyNowLine,
      })
    );
  };

  // Calculate savings (mock 20% discount)
  const currentPrice = item.variant?.price || item.product.price;
  const originalPrice = item.product.originalPrice?.amount || (currentPrice * 1.2); // Fallback mock
  const savings = Math.round(originalPrice - currentPrice);

  const getImageUrl = () => {
    const imageUrl = item.product.thumbnail?.url || item.product.images?.[0]?.url;
    if (imageUrl) {
      return fixImageUrl(imageUrl);
    }
    return 'https://via.placeholder.com/100';
  };

  const renderRightActions = () => (
    <View style={styles.swipeActions}>
      <TouchableOpacity
        style={styles.removeAction}
        onPress={handleRemove}
      >
        <MaterialCommunityIcons name="delete" size={24} color="white" />
        <Text style={styles.removeActionText}>Remove</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <Swipeable renderRightActions={renderRightActions} ref={swipeableRef}>
      <AnimatedCard style={[styles.card, animatedStyle]}>
        <TouchableOpacity
          style={styles.itemContent}
          onPress={() => onPress(item)}
          onPressIn={handlePressIn}
          onPressOut={handlePressOut}
          activeOpacity={1}
        >
          <View style={styles.itemRow}>
            {/* Product Image */}
            <Image
              source={{ uri: getImageUrl() }}
              style={styles.itemImage}
              resizeMode="cover"
            />

            {/* Product Details */}
            <View style={styles.itemDetails}>
              <Text variant="titleMedium" numberOfLines={2} style={styles.itemName}>
                {item.product.name}
              </Text>

              {item.variant && (
                <Text variant="bodySmall" style={styles.variant}>
                  Variant: {item.variant.name}
                </Text>
              )}

              <View style={styles.priceRow}>
                {savings > 0 && (
                  <Text style={styles.originalPrice}>
                    {formatCurrency(originalPrice, item.product.currency)}
                  </Text>
                )}
                <Text variant="titleSmall" style={[styles.price, { color: theme.colors.primary }]}>
                  {formatCurrency(currentPrice, item.product.currency)}
                </Text>
              </View>

              {savings > 0 && (
                <Text style={styles.savings}>
                  You save ₹{savings}
                </Text>
              )}

              <View style={styles.deliveryInfo}>
                <MaterialCommunityIcons
                  name="truck-delivery"
                  size={16}
                  color={theme.colors.primary}
                />
                <Text style={styles.deliveryText}>
                  Delivery by {deliveryDateString}
                </Text>
              </View>
            </View>

            {/* Quantity Controls */}
            <View style={styles.quantitySection}>
              <View style={styles.quantityControls}>
                <IconButton
                  icon="minus"
                  size={16}
                  onPress={() => handleQuantityChange(-1)}
                  disabled={item.quantity <= 1}
                  style={styles.quantityButton}
                />
                <Text style={styles.quantity}>{item.quantity}</Text>
                <IconButton
                  icon="plus"
                  size={16}
                  onPress={() => handleQuantityChange(1)}
                  disabled={item.quantity >= maxQuantity || !isInStock}
                  style={styles.quantityButton}
                />
              </View>

              {/* Stock Status */}
              <View style={styles.stockInfo}>
                {!isInStock ? (
                  <Text style={styles.outOfStock}>Out of Stock</Text>
                ) : availableStock <= 5 ? (
                  <Text style={styles.lowStock}>Only {availableStock} left</Text>
                ) : item.quantity >= maxQuantity ? (
                  <Text style={styles.maxQuantity}>Max quantity reached</Text>
                ) : null}
              </View>
            </View>
          </View>
        </TouchableOpacity>

        {/* Action Buttons */}
        <View style={styles.actionButtonsContainer}>
          <Button
            mode="outlined"
            icon="delete"
            onPress={handleRemove}
            style={[styles.actionButton, styles.removeActionButton]}
            labelStyle={styles.removeButtonLabel}
            compact
          >
            Remove
          </Button>

          <Button
            mode="contained"
            icon="lightning-bolt"
            onPress={handleBuyNow}
            style={[styles.actionButton, styles.buyNowButton]}
            labelStyle={styles.buyNowButtonLabel}
            compact
          >
            Buy Now
          </Button>
        </View>
      </AnimatedCard>

      {/* Snackbar for user feedback */}
      <Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={3000}
        style={styles.snackbar}
      >
        {snackbarMessage}
      </Snackbar>
    </Swipeable>
  );
}

const styles = StyleSheet.create({
  card: {
    marginHorizontal: spacing.md,
    marginBottom: spacing.sm,
    overflow: 'hidden',
  },
  itemContent: {
    padding: spacing.md,
  },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  itemImage: {
    width: 80,
    height: 80,
    borderRadius: 8,
    marginRight: spacing.md,
  },
  itemDetails: {
    flex: 1,
    marginRight: spacing.sm,
  },
  itemName: {
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  variant: {
    opacity: 0.7,
    marginBottom: spacing.xs,
  },
  priceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  originalPrice: {
    textDecorationLine: 'line-through',
    opacity: 0.6,
    fontSize: 12,
    marginRight: spacing.xs,
  },
  price: {
    fontWeight: '600',
  },
  savings: {
    color: '#4CAF50',
    fontSize: 12,
    fontWeight: '500',
    marginBottom: spacing.xs,
  },
  deliveryInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  deliveryText: {
    marginLeft: spacing.xs,
    fontSize: 12,
    opacity: 0.7,
  },
  quantitySection: {
    alignItems: 'center',
  },
  quantityControls: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    backgroundColor: '#F5F5F5',
  },
  quantityButton: {
    margin: 0,
    width: 32,
    height: 32,
  },
  quantity: {
    paddingHorizontal: spacing.sm,
    fontWeight: '600',
    minWidth: 30,
    textAlign: 'center',
  },
  actionButtonsContainer: {
    flexDirection: 'row',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    gap: spacing.sm,
  },
  actionButton: {
    flex: 1,
    borderRadius: 8,
  },
  removeActionButton: {
    borderColor: '#F44336',
  },
  removeButtonLabel: {
    color: '#F44336',
    fontSize: 12,
  },
  buyNowButton: {
    backgroundColor: '#FF6B35',
  },
  buyNowButtonLabel: {
    color: '#FFFFFF',
    fontSize: 12,
  },
  swipeActions: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'flex-end',
    paddingRight: spacing.md,
  },
  removeAction: {
    backgroundColor: '#F44336',
    justifyContent: 'center',
    alignItems: 'center',
    width: 80,
    height: '90%',
    borderRadius: 8,
    marginVertical: spacing.xs,
  },
  removeActionText: {
    color: 'white',
    fontSize: 12,
    fontWeight: '600',
    marginTop: spacing.xs,
  },
  stockInfo: {
    marginTop: spacing.xs,
    alignItems: 'center',
  },
  outOfStock: {
    color: '#F44336',
    fontSize: 10,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  lowStock: {
    color: '#FF9800',
    fontSize: 10,
    fontWeight: '500',
  },
  maxQuantity: {
    color: '#757575',
    fontSize: 10,
    fontWeight: '500',
  },
  snackbar: {
    bottom: 100,
  },
});
