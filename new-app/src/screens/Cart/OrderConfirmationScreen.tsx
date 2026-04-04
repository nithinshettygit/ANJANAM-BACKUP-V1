import React, { useEffect } from 'react';
import { View, StyleSheet, ScrollView } from 'react-native';
import { Text, Button, Card, Divider, useTheme } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { clearCart } from '@/store/slices/cartSlice';
import type { RootState } from '@/store';
import { formatCurrency, formatDate } from '@/utils/format';
import { spacing } from '@/theme';

export default function OrderConfirmationScreen({ route, navigation }: any) {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const user = useAppSelector((state: RootState) => state.auth.user);
  const { order, orderId, form, cart } = route.params || {};

  console.log('OrderConfirmation received params:', { order, orderId, form, cart });

  // Handle both new order object format and legacy format
  const orderData = order || {
    id: orderId,
    orderNumber: orderId,
    paymentMethod: form?.paymentMethod || 'razorpay',
    paymentStatus: form?.paymentMethod === 'cod' ? 'PENDING' : 'PAID',
    total: cart?.total || 0,
    currency: cart?.currency || 'INR',
    createdAt: new Date().toISOString(),
    shippingAddress: {
      name: form?.name,
      phone: form?.phone,
      email: form?.email,
      addressLine1: form?.address,
      city: form?.city,
      state: form?.state,
      postalCode: form?.pincode,
      country: 'IN',
    },
    items: cart?.items || [],
    subtotal: cart?.subtotal || 0,
    tax: cart?.tax || 0,
    shipping: cart?.shipping || 0,
    discount: cart?.discount || 0,
  };

  const isCodOrder = orderData.paymentMethod === 'COD';
  const isPaidOrder = !isCodOrder && orderData.paymentStatus === 'PAID';

  useEffect(() => {
    // Clear cart after order placement (only for legacy format)
    if (!order) {
      dispatch(clearCart());
    }
  }, [dispatch, order]);

  const handleContinueShopping = () => {
    navigation.navigate('Main');
  };

  const handleViewOrders = () => {
    navigation.navigate('Orders');
  };

  return (
    <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
      {/* Success Icon */}
      <View style={styles.iconContainer}>
        <View style={[styles.iconCircle, { backgroundColor: theme.colors.primaryContainer }]}>
          <MaterialCommunityIcons
            name={isCodOrder ? "clock-outline" : "check-circle"}
            size={80}
            color={theme.colors.primary}
          />
        </View>
        <Text variant="headlineMedium" style={styles.successTitle}>
          {isCodOrder ? 'Order Created (COD)' : 'Order Placed Successfully!'}
        </Text>
        <Text variant="bodyLarge" style={styles.successMessage}>
          {isCodOrder
            ? 'Pay when you receive your order'
            : 'Thank you for your order'
          }
        </Text>

        {/* Payment Status Badge */}
        <View style={[styles.paymentBadge, {
          backgroundColor: isCodOrder ? '#FFF3E0' : '#E8F5E8',
          borderColor: isCodOrder ? '#FF9800' : '#4CAF50'
        }]}>
          <MaterialCommunityIcons
            name={isCodOrder ? "cash" : "credit-card-check"}
            size={20}
            color={isCodOrder ? '#F57C00' : '#2E7D32'}
          />
          <Text variant="bodyMedium" style={[styles.paymentBadgeText, {
            color: isCodOrder ? '#F57C00' : '#2E7D32'
          }]}>
            {isCodOrder ? 'Cash on Delivery' : 'Paid via Razorpay'}
          </Text>
        </View>
      </View>

      {/* Order Details */}
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleLarge" style={styles.sectionTitle}>
            Order Details
          </Text>
          <Divider style={styles.divider} />

          <View style={styles.detailRow}>
            <Text variant="bodyLarge" style={styles.label}>
              Order ID:
            </Text>
            <Text variant="bodyLarge" style={styles.value}>
              #{orderData.orderNumber || orderData.id}
            </Text>
          </View>

          <View style={styles.detailRow}>
            <Text variant="bodyLarge" style={styles.label}>
              Date:
            </Text>
            <Text variant="bodyLarge" style={styles.value}>
              {formatDate(new Date(orderData.createdAt || Date.now()))}
            </Text>
          </View>

          <View style={styles.detailRow}>
            <Text variant="bodyLarge" style={styles.label}>
              Total Amount:
            </Text>
            <Text variant="bodyLarge" style={[styles.value, { color: theme.colors.primary, fontWeight: 'bold' }]}>
              {formatCurrency(orderData.total, orderData.currency)}
            </Text>
          </View>

          <View style={styles.detailRow}>
            <Text variant="bodyLarge" style={styles.label}>
              Payment Method:
            </Text>
            <Text variant="bodyLarge" style={styles.value}>
              {isCodOrder ? 'Cash on Delivery' : 'Razorpay'}
            </Text>
          </View>

          <View style={styles.detailRow}>
            <Text variant="bodyLarge" style={styles.label}>
              Payment Status:
            </Text>
            <Text variant="bodyLarge" style={[styles.value, {
              color: isCodOrder ? '#F57C00' : '#2E7D32',
              fontWeight: '600'
            }]}>
              {isCodOrder ? 'Pending' : 'Paid'}
            </Text>
          </View>
        </Card.Content>
      </Card>

      {/* Delivery Address */}
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleLarge" style={styles.sectionTitle}>
            Delivery Address
          </Text>
          <Divider style={styles.divider} />

          <Text variant="bodyLarge" style={styles.addressText}>
            {orderData.shippingAddress?.name || 'Customer'}
          </Text>
          <Text variant="bodyMedium" style={styles.addressText}>
            {orderData.shippingAddress?.addressLine1}
          </Text>
          <Text variant="bodyMedium" style={styles.addressText}>
            {orderData.shippingAddress?.city}, {orderData.shippingAddress?.state} - {orderData.shippingAddress?.postalCode}
          </Text>
          <Text variant="bodyMedium" style={styles.addressText}>
            Phone: {orderData.shippingAddress?.phone}
          </Text>
          <Text variant="bodyMedium" style={styles.addressText}>
            Email: {orderData.shippingAddress?.email}
          </Text>
        </Card.Content>
      </Card>

      {/* Order Items */}
      {orderData.items && orderData.items.length > 0 && (
        <Card style={styles.card}>
          <Card.Content>
            <Text variant="titleLarge" style={styles.sectionTitle}>
              Order Items ({orderData.items.length})
            </Text>
            <Divider style={styles.divider} />

            {orderData.items.map((item: any, index: number) => (
              <View key={item.id || index}>
                <View style={styles.itemRow}>
                  <View style={styles.itemDetails}>
                    <Text variant="titleMedium" numberOfLines={1}>
                      {item.product?.name || 'Product'}
                    </Text>
                    {item.variant && (
                      <Text variant="bodySmall" style={styles.itemVariant}>
                        {item.variant?.name || 'Variant'}
                      </Text>
                    )}
                    <Text variant="bodyMedium">
                      Qty: {item.quantity} × {formatCurrency(item.price || item.variant?.price || item.product?.price || 0, orderData.currency)}
                    </Text>
                  </View>
                  <Text variant="titleMedium" style={styles.itemPrice}>
                    {formatCurrency(item.total || (item.quantity * (item.price || item.variant?.price || item.product?.price || 0)), orderData.currency)}
                  </Text>
                </View>
                {index < orderData.items.length - 1 && <Divider style={styles.itemDivider} />}
              </View>
            ))}

            <Divider style={styles.divider} />

            {/* Price Breakdown */}
            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Subtotal</Text>
              <Text variant="bodyLarge">{formatCurrency(orderData.subtotal, orderData.currency)}</Text>
            </View>

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Tax (18% GST)</Text>
              <Text variant="bodyLarge">{formatCurrency(orderData.tax, orderData.currency)}</Text>
            </View>

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Shipping</Text>
              <Text variant="bodyLarge">
                {orderData.shipping === 0 ? 'FREE' : formatCurrency(orderData.shipping, orderData.currency)}
              </Text>
            </View>

            {orderData.discount > 0 && (
              <View style={styles.summaryRow}>
                <Text variant="bodyLarge" style={styles.discountText}>Discount</Text>
                <Text variant="bodyLarge" style={styles.discountText}>
                  -{formatCurrency(orderData.discount, orderData.currency)}
                </Text>
              </View>
            )}

            <Divider style={styles.divider} />

            <View style={styles.totalRow}>
              <Text variant="titleLarge" style={styles.totalLabel}>Total</Text>
              <Text variant="titleLarge" style={[styles.totalAmount, { color: theme.colors.primary }]}>
                {formatCurrency(orderData.total, orderData.currency)}
              </Text>
            </View>
          </Card.Content>
        </Card>
      )}

      {/* Estimated Delivery */}
      <Card style={styles.card}>
        <Card.Content>
          <View style={styles.deliveryInfo}>
            <MaterialCommunityIcons
              name="truck-delivery"
              size={24}
              color={theme.colors.primary}
            />
            <View style={styles.deliveryText}>
              <Text variant="bodyLarge" style={styles.deliveryLabel}>
                Estimated Delivery
              </Text>
              <Text variant="bodyMedium" style={styles.deliveryDate}>
                {formatDate(new Date(Date.now() + 5 * 24 * 60 * 60 * 1000))} (5-7 business days)
              </Text>
            </View>
          </View>
        </Card.Content>
      </Card>

      {/* Guest: Create Account Option */}
      {
        !user && (
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.createAccountHeader}>
                <MaterialCommunityIcons name="account-plus-outline" size={24} color={theme.colors.primary} />
                <Text variant="titleLarge" style={styles.createAccountTitle}>
                  Create an Account
                </Text>
              </View>
              <Text variant="bodyMedium" style={styles.createAccountText}>
                Save your details for faster checkout securely next time.
              </Text>
              <Button
                mode="contained-tonal"
                onPress={() => navigation.navigate('Register', { email: orderData.shippingAddress?.email })}
                style={styles.createAccountButton}
              >
                Create Account with {orderData.shippingAddress?.email}
              </Button>
            </Card.Content>
          </Card>
        )
      }

      {/* Action Buttons */}
      <View style={styles.buttonsContainer}>
        <Button
          mode="contained"
          icon="shopping"
          onPress={handleContinueShopping}
          style={styles.button}
        >
          Continue Shopping
        </Button>
        <Button
          mode="outlined"
          icon="package-variant"
          onPress={handleViewOrders}
          style={styles.button}
        >
          View All Orders
        </Button>
      </View>

      <View style={styles.bottomSpacer} />
    </ScrollView >
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  iconContainer: {
    alignItems: 'center',
    paddingVertical: spacing.xxl,
  },
  iconCircle: {
    width: 120,
    height: 120,
    borderRadius: 60,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  successTitle: {
    fontWeight: 'bold',
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  successMessage: {
    opacity: 0.7,
    textAlign: 'center',
  },
  paymentBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: 20,
    borderWidth: 1,
    marginTop: spacing.md,
    alignSelf: 'center',
  },
  paymentBadgeText: {
    marginLeft: spacing.xs,
    fontWeight: '600',
  },
  card: {
    margin: spacing.md,
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontWeight: 'bold',
    marginBottom: spacing.sm,
  },
  divider: {
    marginVertical: spacing.sm,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  label: {
    opacity: 0.7,
  },
  value: {
    fontWeight: '500',
  },
  addressText: {
    marginBottom: spacing.xs,
  },
  itemRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  itemDetails: {
    flex: 1,
    marginRight: spacing.md,
  },
  itemVariant: {
    opacity: 0.7,
    marginTop: spacing.xs,
  },
  itemPrice: {
    fontWeight: '600',
  },
  itemDivider: {
    marginVertical: spacing.sm,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  discountText: {
    color: '#4CAF50',
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
  deliveryInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  deliveryText: {
    marginLeft: spacing.md,
  },
  deliveryLabel: {
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  deliveryDate: {
    opacity: 0.7,
  },
  buttonsContainer: {
    padding: spacing.md,
    gap: spacing.md,
  },
  button: {
    borderRadius: 8,
  },
  bottomSpacer: {
    height: spacing.xl,
  },
  createAccountHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xs,
    gap: spacing.sm,
  },
  createAccountTitle: {
    fontWeight: 'bold',
  },
  createAccountText: {
    marginBottom: spacing.md,
    opacity: 0.7,
  },
  createAccountButton: {
    marginTop: spacing.xs,
  },
});
