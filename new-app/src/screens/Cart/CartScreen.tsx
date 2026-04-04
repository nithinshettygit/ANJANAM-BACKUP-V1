import React from 'react';
import { View, StyleSheet, ScrollView } from 'react-native';
import { Appbar, Text, Button, Divider, Card, useTheme } from 'react-native-paper';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { removeFromCart, updateQuantity, clearCart } from '@/store/slices/cartSlice';
import { clearBuyNow } from '@/store/slices/buyNowSlice';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import EmptyState from '@/components/common/EmptyState';
import SwipeableCartItem from '@/components/cart/SwipeableCartItem';
import type { RootState } from '@/store';

export default function CartScreen({ navigation }: any) {
  const dispatch = useAppDispatch();
  const theme = useTheme();
  const cart = useAppSelector((state: RootState) => state.cart.cart);
  const { items } = cart;

  const handleUpdateQuantity = (itemId: string, delta: number) => {
    const item = items.find((i) => i.id === itemId);
    if (!item) return;
    const newQuantity = item.quantity + delta;
    if (newQuantity > 0 && newQuantity <= 10) {
      dispatch(updateQuantity({ itemId, quantity: newQuantity }));
    }
  };

  const handleRemoveItem = (itemId: string) => {
    dispatch(removeFromCart(itemId));
  };

  const handleClearCart = () => {
    dispatch(clearCart());
  };

  const handleCheckout = () => {
    dispatch(clearBuyNow());
    navigation.navigate('CheckoutAddress', { flow: 'cart' });
  };


  const handleItemPress = (item: any) => {
    // Navigate to product detail screen
    navigation.navigate('ProductDetail', { productId: item.product.id });
  };

  if (items.length === 0) {
    return (
      <View style={styles.container}>
        <EmptyState
          icon="cart-outline"
          title="Your cart is empty"
          message="Add products to your cart to see them here. Start shopping now!"
          actionLabel="Start Shopping"
          onAction={() => navigation.navigate('Main')}
        />
      </View>
    );
  }

  return (
    <View style={styles.container}>

      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Cart Items */}
        <View style={styles.itemsContainer}>
          {items.map((item) => (
            <SwipeableCartItem
              key={item.id}
              item={item}
              onRemove={handleRemoveItem}
              onUpdateQuantity={handleUpdateQuantity}
              onPress={handleItemPress}
            />
          ))}
        </View>

        {/* Summary */}
        <Card style={styles.summaryCard}>
          <Card.Content>
            <Text variant="titleLarge" style={styles.summaryTitle}>
              Order Summary
            </Text>
            <Divider style={styles.divider} />

            {/* Summary Rows */}
            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Subtotal</Text>
              <Text variant="bodyLarge">{formatCurrency(cart.subtotal, 'INR')}</Text>
            </View>

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Tax (18% GST)</Text>
              <Text variant="bodyLarge">{formatCurrency(cart.tax, 'INR')}</Text>
            </View>

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Shipping</Text>
              {cart.shipping === 0 ? (
                <Text variant="bodyLarge" style={styles.freeShipping}>
                  FREE
                </Text>
              ) : (
                <Text variant="bodyLarge">{formatCurrency(cart.shipping, 'INR')}</Text>
              )}
            </View>

            {cart.shipping > 0 && cart.subtotal < 500 && (
              <Text variant="bodySmall" style={styles.shippingNote}>
                Add {formatCurrency(500 - cart.subtotal, 'INR')} more for free shipping!
              </Text>
            )}

            <Divider style={styles.divider} />

            <View style={styles.totalRow}>
              <Text variant="titleLarge" style={styles.totalLabel}>
                Total
              </Text>
              <Text variant="titleLarge" style={[styles.totalAmount, { color: theme.colors.primary }]}>
                {formatCurrency(cart.total, 'INR')}
              </Text>
            </View>
          </Card.Content>
        </Card>

        <View style={styles.bottomSpacer} />
      </ScrollView>

      {/* Checkout Button */}
      <View style={[styles.checkoutContainer, { backgroundColor: theme.colors.surface }]}>
        <Button
          mode="contained"
          icon="shopping"
          onPress={handleCheckout}
          style={styles.checkoutButton}
          contentStyle={styles.checkoutButtonContent}
        >
          Proceed to Checkout
        </Button>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  itemsContainer: {
    padding: spacing.md,
  },
  itemCard: {
    marginBottom: 0,
  },
  itemContent: {
    flexDirection: 'row',
    padding: spacing.md,
  },
  itemImage: {
    width: 80,
    height: 80,
    borderRadius: 8,
    backgroundColor: '#F5F5F5',
  },
  itemDetails: {
    flex: 1,
    marginLeft: spacing.md,
    marginRight: spacing.sm,
  },
  itemName: {
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  itemVariant: {
    opacity: 0.7,
    marginBottom: spacing.xs,
  },
  itemPrice: {
    fontWeight: '600',
    marginBottom: spacing.sm,
  },
  quantityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
  },
  quantityButton: {
    margin: 0,
  },
  quantityText: {
    marginHorizontal: spacing.sm,
    fontWeight: '600',
    minWidth: 24,
    textAlign: 'center',
  },
  removeButton: {
    margin: 0,
  },
  itemSubtotal: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
  },
  subtotalAmount: {
    fontWeight: '600',
  },
  itemSpacer: {
    height: spacing.md,
  },
  summaryCard: {
    margin: spacing.md,
    marginTop: spacing.sm,
  },
  summaryTitle: {
    fontWeight: 'bold',
    marginBottom: spacing.sm,
  },
  divider: {
    marginVertical: spacing.md,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  freeShipping: {
    color: '#4CAF50',
    fontWeight: '600',
  },
  shippingNote: {
    color: '#FF9800',
    marginTop: spacing.xs,
    fontStyle: 'italic',
  },
  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  totalLabel: {
    fontWeight: 'bold',
  },
  totalAmount: {
    fontWeight: 'bold',
  },
  bottomSpacer: {
    height: spacing.xl,
  },
  checkoutContainer: {
    padding: spacing.md,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  checkoutButton: {
    borderRadius: 8,
  },
  checkoutButtonContent: {
    paddingVertical: spacing.sm,
  },
  actionButtonsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
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
    backgroundColor: '#FF6B35', // Keep orange for "Buy Now" to distinguish from "Add to Cart"
  },
  buyNowButtonLabel: {
    color: '#FFFFFF',
    fontSize: 12,
  },
});
