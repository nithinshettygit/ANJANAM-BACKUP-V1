import React, { useState } from 'react';
import { View, StyleSheet, Alert, Platform } from 'react-native';
import { Text, Button, RadioButton, Card, Divider, useTheme, ActivityIndicator } from 'react-native-paper';
import RazorpayCheckout from 'react-native-razorpay';

import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import type { RootState } from '@/store';
import { createRazorpayOrder, createCodOrder, verifyRazorpayPayment, type CreateRazorpayOrderPayload } from '@/services/payments';
import { addOrder } from '@/store/slices/userSlice';
import { clearCart } from '@/store/slices/cartSlice';
import { clearBuyNow } from '@/store/slices/buyNowSlice';
import { API_CONFIG } from '@/constants';
import { OrderStatus, PaymentStatus } from '@/types';
import { buildBuyNowCartSummary } from '@/utils/checkoutTotals';

export default function PaymentMethodScreen({ navigation, route }: any) {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const cart = useAppSelector((state: RootState) => state.cart.cart);
  const buyNow = useAppSelector((state: RootState) => state.buyNow);
  const user = useAppSelector((state: RootState) => state.auth.user);
  const { address, flow: routeFlow = 'cart', buyNowLine: buyNowLineParam } = route.params || {};
  const isBuyNow = Boolean(buyNowLineParam) || Boolean(buyNow.item);
  const flow = isBuyNow ? 'buy_now' : routeFlow;

  const data = buyNowLineParam
    ? buildBuyNowCartSummary(buyNowLineParam)
    : buyNow.item
      ? {
          items: [
            {
              product: buyNow.item.product,
              variant: buyNow.item.variant,
              quantity: buyNow.item.quantity,
              price: buyNow.item.price,
            },
          ],
          subtotal: buyNow.subtotal,
          tax: buyNow.tax,
          shipping: buyNow.shipping,
          discount: 0,
          total: buyNow.total,
          currency: buyNow.currency,
        }
      : cart;

  const [paymentMethod, setPaymentMethod] = useState<'razorpay' | 'cod'>('razorpay');
  const [loading, setLoading] = useState(false);

  // Helper to handle success from either Native SDK or Simulation
  const handleRazorpaySuccess = async (saleorOrderId: string, checkoutData: any) => {
    setLoading(true);
    try {
      const verifyRes = await verifyRazorpayPayment({
        saleorOrderId: saleorOrderId,
        razorpayOrderId: checkoutData.razorpay_order_id,
        razorpayPaymentId: checkoutData.razorpay_payment_id,
        razorpaySignature: checkoutData.razorpay_signature
      });

      if (verifyRes.success && verifyRes.data) {
        if (isBuyNow) {
          dispatch(clearBuyNow());
        } else {
          dispatch(clearCart());
        }
        navigation.replace('OrderConfirmation', {
          order: {
            ...verifyRes.data.order,
            createdAt: verifyRes.data.order.createdAt || new Date().toISOString()
          }
        });
      } else {
        Alert.alert('Payment Verification Failed', verifyRes.error?.message || 'Please contact support.');
        setLoading(false);
      }
    } catch (e) {
      Alert.alert('Error', 'Verification failed');
      setLoading(false);
    }
  };

  const handlePayment = async () => {
    // if (!user) {
    //   Alert.alert('Error', 'User not logged in');
    //   return;
    // }

    setLoading(true);

    const payload: CreateRazorpayOrderPayload = {
      checkoutType: isBuyNow ? 'buy_now' : 'cart',
      saleorChannel: API_CONFIG.SALEOR_CHANNEL,
      items: data.items.map((item: any) => ({
        productId: item.product.id,
        variantId: item.variant?.id,
        quantity: item.quantity,
        unitPrice: item.variant?.price || item.product.price || item.price,
        totalPrice: (item.variant?.price || item.product.price || item.price) * item.quantity
      })),
      amounts: {
        subtotal: data.subtotal,
        tax: data.tax,
        shipping: data.shipping,
        discount: data.discount,
        total: data.total,
        currency: data.currency
      },
      customer: {
        userId: user?.id, // Optional now
        name: address.name,
        email: user?.email || address.email || 'guest@example.com',
        phone: address.phone
      },
      shippingAddress: {
        name: address.name,
        phone: address.phone,
        email: user?.email || address.email || 'guest@example.com',
        addressLine1: address.address, // Backend expects addressLine1
        city: address.city,
        state: address.state,
        postalCode: address.pincode, // Backend expects postalCode
        country: 'IN'
      },
      paymentMethod: paymentMethod
    };

    try {
      if (paymentMethod === 'cod') {
        const response = await createCodOrder(payload);
        if (response.success && response.data) {
          const orderData = response.data;
          // Create minimal order object for redux (in real app, fetch full order)
          // We'll navigate to confirmation which can ideally fetch it or we pass a constructed one
          const order = {
            id: orderData.saleorOrderId,
            orderNumber: orderData.saleorOrderNumber,
            items: data.items,
            shippingAddress: {
              // Store as ShippingAddress format for UI
              name: address.name,
              phone: address.phone,
              email: user?.email || address.email || 'guest@example.com',
              addressLine1: address.address,
              city: address.city,
              state: address.state,
              postalCode: address.pincode,
              country: 'IN'
            },
            paymentStatus: 'PENDING',
            paymentMethod: 'COD',
            total: data.total,
            subtotal: data.subtotal,
            currency: data.currency,
            createdAt: new Date().toISOString(), // Critical: Pass creation time
          };

          if (isBuyNow) {
            dispatch(clearBuyNow());
          } else {
            dispatch(clearCart());
          }
          // dispatch(addOrder(order)); // If we have redux persistence
          navigation.replace('OrderConfirmation', { order });
        } else {
          Alert.alert('Error', response.error?.message || 'Failed to place COD order');
        }
      } else {
        // Razorpay
        const response = await createRazorpayOrder(payload);
        if (response.success && response.data) {
          const data = response.data;
          const options = {
            description: `Order #${data.saleorOrderNumber}`,
            image: 'https://your-logo-url.com/logo.png', // Optional
            currency: data.currency,
            key: data.razorpayKeyId,
            amount: data.amount, // in paise
            name: 'ANJANAM',
            order_id: data.razorpayOrderId,
            prefill: {
              email: user?.email || address.email,
              contact: address.phone,
              name: address.name
            },
            theme: { color: theme.colors.primary }
          };

          // Safe Razorpay handling for Expo Go
          // Safe Razorpay handling for Expo Go
          if (RazorpayCheckout) {
            RazorpayCheckout.open(options).then(async (checkoutData: any) => {
              // Success
              handleRazorpaySuccess(data.saleorOrderId, checkoutData);
            }).catch((error: any) => {
              // Error or Cancel
              console.log('Razorpay Error:', error);
              let errorMsg = 'Payment cancelled or failed';
              if (error && error.description) {
                errorMsg = error.description;
              }
              try {
                const errorObj = JSON.parse(error.error);
                errorMsg = errorObj.description || errorMsg;
              } catch (e) { }

              Alert.alert('Payment Failed', errorMsg);
              setLoading(false);
            });
          } else {
            // Fallback for Expo Go (Simulation)
            console.log('Razorpay Native Module not found (Expo Go detected). Simulating...');
            Alert.alert(
              'Simulation Mode',
              'Native Razorpay SDK is not available in Expo Go. Simulate successful payment?',
              [
                {
                  text: 'Cancel',
                  onPress: () => setLoading(false),
                  style: 'cancel'
                },
                {
                  text: 'Simulate Success',
                  onPress: () => {
                    const mockData = {
                      razorpay_order_id: data.razorpayOrderId,
                      razorpay_payment_id: 'pay_simulated_' + Date.now(),
                      razorpay_signature: 'SIMULATED_SIGNATURE'
                    };
                    handleRazorpaySuccess(data.saleorOrderId, mockData);
                  }
                }
              ]
            );
          }
        } else {
          Alert.alert('Error', response.error?.message || 'Failed to initiate payment');
          setLoading(false);
        }
      }
    } catch (e: any) {
      Alert.alert('Error', e.message || 'An unexpected error occurred');
    } finally {
      if (paymentMethod === 'cod') {
        setLoading(false);
      } else {
        // For Razorpay, loading is handled in the .then/.catch blocks or cleared if initiate fails
        // If initiate failed (response.success false):
        setLoading(false);
        // Note: if Razorpay opens, it handles its own UI, but we might want to unset loading.
        // However, separating initiate vs open is tricky in async flow.
        // Simple approach: set loading false after initiate call if we are just opening modal.
      }
    }
  };

  return (
    <View style={styles.container}>
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.header}>Select Payment Method</Text>
          <Divider style={styles.divider} />

          <RadioButton.Group onValueChange={value => setPaymentMethod(value as any)} value={paymentMethod}>
            <View style={styles.optionRow}>
              <RadioButton value="razorpay" />
              <View>
                <Text variant="titleMedium">UPI / Cards / Netbanking</Text>
                <Text variant="bodySmall" style={styles.subtext}>Pay online securely via Razorpay</Text>
              </View>
            </View>
            <Divider style={styles.divider} />
            <View style={styles.optionRow}>
              <RadioButton value="cod" />
              <View>
                <Text variant="titleMedium">Cash on Delivery</Text>
                <Text variant="bodySmall" style={styles.subtext}>Pay when you receive the order</Text>
              </View>
            </View>
          </RadioButton.Group>
        </Card.Content>
      </Card>

      <View style={styles.footer}>
        <View style={styles.totalContainer}>
          <Text variant="headlineSmall" style={styles.total}>{formatCurrency(data.total, 'INR')}</Text>
          <Text variant="bodySmall">Total Amount</Text>
        </View>
        <Button
          mode="contained"
          onPress={handlePayment}
          loading={loading}
          disabled={loading}
          style={styles.payButton}
        >
          {paymentMethod === 'cod' ? 'Place Order' : 'Pay Securely'}
        </Button>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
    padding: spacing.md,
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 4,
  },
  header: {
    marginBottom: spacing.sm,
    fontWeight: 'bold',
  },
  divider: {
    marginVertical: spacing.sm,
  },
  optionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  subtext: {
    color: '#666',
  },
  footer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'white',
    padding: spacing.md,
    elevation: 8,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  totalContainer: {
    flex: 1,
  },
  total: {
    fontWeight: 'bold',
    color: '#000',
  },
  payButton: {
    flex: 1,
    borderRadius: 0, // Flipkart style often square-ish or simple
    backgroundColor: '#FB641B',
  },
});
