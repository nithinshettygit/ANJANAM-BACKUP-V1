import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, KeyboardAvoidingView, Platform } from 'react-native';
import { Appbar, Text, TextInput, Button, RadioButton, Card, Divider, useTheme, Snackbar } from 'react-native-paper';
import { useAppDispatch, useAppSelector } from '@/hooks/useTypedSelector';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import { APP_CONFIG, API_CONFIG, ERROR_MESSAGES, SUCCESS_MESSAGES } from '@/constants';
import type { RootState } from '@/store';
import type { RazorpayOptions } from '@/types';
import { OrderStatus, PaymentStatus } from '@/types';
import RealRazorpayPayment from '@/components/payments/RealRazorpayPayment';
import { createRazorpayOrder, verifyRazorpayPayment, createCodOrder, type CreateRazorpayOrderData, type CreateRazorpayOrderPayload } from '@/services/payments';
import { addOrder } from '@/store/slices/userSlice';
import { clearCart } from '@/store/slices/cartSlice';

interface CheckoutForm {
  name: string;
  email: string;
  phone: string;
  address: string;
  city: string;
  state: string;
  pincode: string;
  paymentMethod: 'razorpay' | 'cod';
}

export default function CheckoutScreen({ navigation }: any) {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const cart = useAppSelector((state: RootState) => state.cart.cart);
  const user = useAppSelector((state: RootState) => state.auth.user);

  const [form, setForm] = useState<CheckoutForm>({
    name: user?.displayName || '',
    email: user?.email || '',
    phone: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    paymentMethod: 'razorpay', // Default to Razorpay
  });

  const [errors, setErrors] = useState<Partial<CheckoutForm>>({});

  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [paymentModalVisible, setPaymentModalVisible] = useState(false);
  const [paymentOptions, setPaymentOptions] = useState<RazorpayOptions | null>(null);
  const [currentOrderMeta, setCurrentOrderMeta] = useState<CreateRazorpayOrderData | null>(null);
  const [snackbarVisible, setSnackbarVisible] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  const [isVerifyingPayment, setIsVerifyingPayment] = useState(false);

  const showSnackbar = (message: string) => {
    setSnackbarMessage(message);
    setSnackbarVisible(true);
  };

  const handleInputChange = (field: keyof CheckoutForm, value: string) => {
    // For payment method, ensure it's properly typed
    if (field === 'paymentMethod') {
      const paymentMethodValue = value as 'razorpay' | 'cod';
      setForm((prev) => ({ ...prev, [field]: paymentMethodValue }));
    } else {
      setForm((prev) => ({ ...prev, [field]: value }));
    }
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  const validateForm = (): boolean => {
    const newErrors: Partial<CheckoutForm> = {};

    if (!form.name.trim()) newErrors.name = 'Name is required';
    if (!form.email.trim()) newErrors.email = 'Email is required';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) newErrors.email = 'Invalid email';
    if (!form.phone.trim()) newErrors.phone = 'Phone is required';
    if (!/^[0-9]{10}$/.test(form.phone)) newErrors.phone = 'Invalid phone number';
    if (!form.address.trim()) newErrors.address = 'Address is required';
    if (!form.city.trim()) newErrors.city = 'City is required';
    if (!form.state.trim()) newErrors.state = 'State is required';
    if (!form.pincode.trim()) newErrors.pincode = 'Pincode is required';
    if (!/^[0-9]{6}$/.test(form.pincode)) newErrors.pincode = 'Invalid pincode';

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handlePlaceOrder = async () => {
    if (!validateForm()) return;

    if (!cart.items.length) {
      showSnackbar('Your cart is empty.');
      return;
    }

    if (form.paymentMethod === 'cod') {
      navigation.navigate('OrderConfirmation', {
        orderId: `ORD-${Date.now()}`,
        form,
        cart,
      });
      return;
    }

    const payload: CreateRazorpayOrderPayload = {
      checkoutType: 'cart' as const,
      saleorChannel: API_CONFIG.SALEOR_CHANNEL,
      items: cart.items.map((item) => {
        const unitPrice = item.variant?.price || item.product.price;
        return {
          productId: item.product.id,
          variantId: item.variant?.id,
          quantity: item.quantity,
          unitPrice,
          totalPrice: unitPrice * item.quantity,
        };
      }),
      amounts: {
        subtotal: cart.subtotal,
        tax: cart.tax,
        shipping: cart.shipping,
        discount: cart.discount,
        total: cart.total,
        currency: cart.currency,
      },
      customer: {
        userId: user?.id,
        name: form.name,
        email: form.email,
        phone: form.phone,
      },
      shippingAddress: {
        name: form.name,
        phone: form.phone,
        email: form.email,
        addressLine1: form.address,
        addressLine2: '',
        city: form.city,
        state: form.state,
        postalCode: form.pincode,
        country: 'IN',
      },
      paymentMethod: form.paymentMethod,
      clientContext: {
        appVersion: APP_CONFIG.APP_VERSION,
        platform: Platform.OS,
      },
    };

    setIsPlacingOrder(true);
    
    // Handle different payment methods
    let response;
    if ((form.paymentMethod as 'razorpay' | 'cod') === 'razorpay') {
      response = await createRazorpayOrder(payload);
    } else {
      response = await createCodOrder(payload);
    }
    
    setIsPlacingOrder(false);

    if (!response.success || !response.data) {
      const message = response.error?.message || ERROR_MESSAGES.SERVER_ERROR;
      showSnackbar(message);
      return;
    }

    const data = response.data;
    setCurrentOrderMeta(data);

    // For COD, directly navigate to confirmation without payment modal
    if ((form.paymentMethod as 'razorpay' | 'cod') === 'cod') {
      // Create order for COD
      const order = {
        id: data.saleorOrderId,
        orderNumber: data.saleorOrderNumber,
        user: user!,
        items: cart.items.map(item => ({
          id: item.id,
          product: item.product,
          variant: item.variant,
          quantity: item.quantity,
          price: item.variant?.price || item.product.price,
          total: (item.variant?.price || item.product.price) * item.quantity,
        })),
        shippingAddress: {
          name: form.name,
          phone: form.phone,
          email: form.email,
          addressLine1: form.address,
          addressLine2: '',
          city: form.city,
          state: form.state,
          postalCode: form.pincode,
          country: 'IN',
        },
        billingAddress: {
          name: form.name,
          phone: form.phone,
          email: form.email,
          addressLine1: form.address,
          addressLine2: '',
          city: form.city,
          state: form.state,
          postalCode: form.pincode,
          country: 'IN',
        },
        subtotal: cart.subtotal,
        tax: cart.tax,
        shipping: cart.shipping,
        discount: cart.discount,
        total: cart.total,
        currency: cart.currency,
        status: OrderStatus.PENDING,
        paymentStatus: PaymentStatus.PENDING,
        paymentMethod: 'COD',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      dispatch(addOrder(order));
      dispatch(clearCart());
      showSnackbar(SUCCESS_MESSAGES.ORDER_PLACED);
      navigation.navigate('OrderConfirmation', { order });
      return;
    }

    // For Razorpay, proceed with payment modal
    const options: RazorpayOptions = {
      key: data.razorpayKeyId,
      amount: data.amount,
      currency: data.currency,
      name: APP_CONFIG.APP_NAME,
      description: `Order ${data.saleorOrderNumber}`,
      order_id: data.razorpayOrderId,
      prefill: {
        name: form.name,
        email: form.email,
        contact: form.phone,
      },
      theme: {
        color: theme.colors.primary,
      },
    };

    setPaymentOptions(options);
    setPaymentModalVisible(true);
  };

  const handlePaymentSuccess = async (payment: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    razorpaySignature: string;
  }) => {
    if (!currentOrderMeta) {
      showSnackbar(ERROR_MESSAGES.PAYMENT_FAILED);
      return;
    }

    setPaymentModalVisible(false);
    setIsPlacingOrder(true);

    // Check if this is a mock payment (test mode)
    const isMockPayment = payment.razorpayPaymentId.startsWith('pay_mock_');
    
    if (isMockPayment) {
      // For mock payments, skip verification and create order directly
      console.log('Mock payment detected, skipping verification');
      
      const order = {
        id: currentOrderMeta.saleorOrderId,
        orderNumber: currentOrderMeta.saleorOrderNumber,
        user: user!,
        items: cart.items.map(item => ({
          id: item.id,
          product: item.product,
          variant: item.variant,
          quantity: item.quantity,
          price: item.variant?.price || item.product.price,
          total: (item.variant?.price || item.product.price) * item.quantity,
        })),
        shippingAddress: {
          name: form.name,
          phone: form.phone,
          email: form.email,
          addressLine1: form.address,
          addressLine2: '',
          city: form.city,
          state: form.state,
          postalCode: form.pincode,
          country: 'IN',
        },
        billingAddress: {
          name: form.name,
          phone: form.phone,
          email: form.email,
          addressLine1: form.address,
          addressLine2: '',
          city: form.city,
          state: form.state,
          postalCode: form.pincode,
          country: 'IN',
        },
        subtotal: cart.subtotal,
        tax: cart.tax,
        shipping: cart.shipping,
        discount: cart.discount,
        total: cart.total,
        currency: cart.currency,
        status: OrderStatus.PENDING,
        paymentStatus: PaymentStatus.PENDING,
        paymentMethod: 'ONLINE',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      setIsPlacingOrder(false);
      dispatch(clearCart());
      dispatch(addOrder(order));
      showSnackbar(SUCCESS_MESSAGES.ORDER_PLACED);
      navigation.navigate('OrderConfirmation', { order });
      return;
    }

    // For real payments, proceed with verification
    const verifyResponse = await verifyRazorpayPayment({
      saleorOrderId: currentOrderMeta.saleorOrderId,
      saleorOrderNumber: currentOrderMeta.saleorOrderNumber,
      razorpayOrderId: payment.razorpayOrderId,
      razorpayPaymentId: payment.razorpayPaymentId,
      razorpaySignature: payment.razorpaySignature,
    });

    setIsPlacingOrder(false);

    if (!verifyResponse.success || !verifyResponse.data) {
      const message = verifyResponse.error?.message || ERROR_MESSAGES.PAYMENT_FAILED;
      showSnackbar(message);
      return;
    }

    const order = verifyResponse.data.order;
    dispatch(clearCart());
    dispatch(addOrder(order));
    showSnackbar(SUCCESS_MESSAGES.ORDER_PLACED);
    navigation.navigate('OrderConfirmation', { order });
  };

  const handlePaymentCancel = () => {
    setPaymentModalVisible(false);
    showSnackbar('Payment cancelled. Your order was not placed.');
  };

  const handlePaymentError = (message: string) => {
    setPaymentModalVisible(false);
    showSnackbar(message || ERROR_MESSAGES.PAYMENT_FAILED);
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >

      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Delivery Address */}
        <Card style={styles.card}>
          <Card.Content>
            <Text variant="titleLarge" style={styles.sectionTitle}>
              Delivery Address
            </Text>

            <TextInput
              label="Full Name *"
              value={form.name}
              onChangeText={(text) => handleInputChange('name', text)}
              error={!!errors.name}
              style={styles.input}
              mode="outlined"
            />
            {errors.name && <Text style={styles.errorText}>{errors.name}</Text>}

            <TextInput
              label="Email *"
              value={form.email}
              onChangeText={(text) => handleInputChange('email', text)}
              error={!!errors.email}
              keyboardType="email-address"
              autoCapitalize="none"
              style={styles.input}
              mode="outlined"
            />
            {errors.email && <Text style={styles.errorText}>{errors.email}</Text>}

            <TextInput
              label="Phone Number *"
              value={form.phone}
              onChangeText={(text) => handleInputChange('phone', text)}
              error={!!errors.phone}
              keyboardType="phone-pad"
              maxLength={10}
              style={styles.input}
              mode="outlined"
            />
            {errors.phone && <Text style={styles.errorText}>{errors.phone}</Text>}

            <TextInput
              label="Address *"
              value={form.address}
              onChangeText={(text) => handleInputChange('address', text)}
              error={!!errors.address}
              multiline
              numberOfLines={3}
              style={styles.input}
              mode="outlined"
            />
            {errors.address && <Text style={styles.errorText}>{errors.address}</Text>}

            <View style={styles.row}>
              <View style={styles.halfInput}>
                <TextInput
                  label="City *"
                  value={form.city}
                  onChangeText={(text) => handleInputChange('city', text)}
                  error={!!errors.city}
                  style={styles.input}
                  mode="outlined"
                />
                {errors.city && <Text style={styles.errorText}>{errors.city}</Text>}
              </View>

              <View style={styles.halfInput}>
                <TextInput
                  label="State *"
                  value={form.state}
                  onChangeText={(text) => handleInputChange('state', text)}
                  error={!!errors.state}
                  style={styles.input}
                  mode="outlined"
                />
                {errors.state && <Text style={styles.errorText}>{errors.state}</Text>}
              </View>
            </View>

            <TextInput
              label="Pincode *"
              value={form.pincode}
              onChangeText={(text) => handleInputChange('pincode', text)}
              error={!!errors.pincode}
              keyboardType="number-pad"
              maxLength={6}
              style={styles.input}
              mode="outlined"
            />
            {errors.pincode && <Text style={styles.errorText}>{errors.pincode}</Text>}
          </Card.Content>
        </Card>

        {/* Payment Method */}
        <Card style={styles.card}>
          <Card.Content>
            <Text variant="titleLarge" style={styles.sectionTitle}>
              Payment Method
            </Text>
            <Divider style={styles.divider} />

            <RadioButton.Group
              onValueChange={(value) => handleInputChange('paymentMethod', value as 'razorpay' | 'cod')}
              value={form.paymentMethod}
            >
              <View style={styles.paymentOption}>
                <RadioButton value="razorpay" />
                <View style={styles.paymentOptionContent}>
                  <Text variant="titleMedium" style={styles.paymentOptionTitle}>
                    Pay Online (Razorpay)
                  </Text>
                  <Text variant="bodySmall" style={styles.paymentOptionDescription}>
                    UPI, Credit/Debit Cards, Wallets
                  </Text>
                </View>
              </View>

              <View style={styles.paymentOption}>
                <RadioButton value="cod" />
                <View style={styles.paymentOptionContent}>
                  <Text variant="titleMedium" style={styles.paymentOptionTitle}>
                    Cash on Delivery (COD)
                  </Text>
                  <Text variant="bodySmall" style={styles.paymentOptionDescription}>
                    Pay when you receive your order
                  </Text>
                </View>
              </View>
            </RadioButton.Group>

            {form.paymentMethod === 'cod' && (
              <View style={styles.codNote}>
                <Text variant="bodySmall" style={styles.codNoteText}>
                  Available only for eligible pin codes
                </Text>
              </View>
            )}
          </Card.Content>
        </Card>

        {/* Order Summary */}
        <Card style={styles.card}>
          <Card.Content>
            <Text variant="titleLarge" style={styles.sectionTitle}>
              Order Summary
            </Text>
            <Divider style={styles.divider} />

            {/* Individual Items */}
            {cart.items.map((item) => (
              <View key={item.id} style={styles.itemRow}>
                <View style={styles.itemInfo}>
                  <Text variant="bodyMedium" numberOfLines={1} style={styles.itemName}>
                    {item.product.name}
                  </Text>
                  {item.variant && (
                    <Text variant="bodySmall" style={styles.itemVariant}>
                      {item.variant.name}
                    </Text>
                  )}
                  <Text variant="bodySmall" style={styles.itemQuantity}>
                    Qty: {item.quantity}
                  </Text>
                </View>
                <Text variant="bodyMedium" style={styles.itemPrice}>
                  {formatCurrency((item.variant?.price || item.product.price) * item.quantity, 'INR')}
                </Text>
              </View>
            ))}
            
            <Divider style={styles.divider} />

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Subtotal ({cart.items.reduce((sum, item) => sum + item.quantity, 0)} items)</Text>
              <Text variant="bodyLarge">{formatCurrency(cart.subtotal, 'INR')}</Text>
            </View>

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Tax (18% GST)</Text>
              <Text variant="bodyLarge">{formatCurrency(cart.tax, 'INR')}</Text>
            </View>

            <View style={styles.summaryRow}>
              <Text variant="bodyLarge">Shipping</Text>
              {cart.shipping === 0 ? (
                <Text variant="bodyLarge" style={styles.freeShipping}>FREE</Text>
              ) : (
                <Text variant="bodyLarge">{formatCurrency(cart.shipping, 'INR')}</Text>
              )}
            </View>

            <Divider style={styles.divider} />

            <View style={styles.totalRow}>
              <Text variant="titleLarge" style={styles.totalLabel}>
                Total Amount
              </Text>
              <Text variant="titleLarge" style={[styles.totalAmount, { color: theme.colors.primary }]}>
                {formatCurrency(cart.total, 'INR')}
              </Text>
            </View>
          </Card.Content>
        </Card>

        <View style={styles.bottomSpacer} />
      </ScrollView>

      {/* Place Order Button */}
      <View style={[styles.buttonContainer, { backgroundColor: theme.colors.surface }]}>
        <Button
          mode="contained"
          icon="check-circle"
          onPress={handlePlaceOrder}
          loading={isPlacingOrder}
          disabled={isPlacingOrder || !cart.items.length}
          style={styles.placeOrderButton}
          contentStyle={styles.placeOrderButtonContent}
        >
          Place Order - {formatCurrency(cart.total, 'INR')}
        </Button>
      </View>

      {paymentModalVisible && paymentOptions && (
        <RealRazorpayPayment
          options={paymentOptions}
          onSuccess={handlePaymentSuccess}
          onCancel={handlePaymentCancel}
          onError={handlePaymentError}
        />
      )}

      <Snackbar
        visible={snackbarVisible}
        onDismiss={() => setSnackbarVisible(false)}
        duration={3000}
      >
        {snackbarMessage}
      </Snackbar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  card: {
    margin: spacing.md,
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontWeight: 'bold',
    marginBottom: spacing.md,
  },
  input: {
    marginBottom: spacing.xs,
  },
  errorText: {
    color: '#F44336',
    fontSize: 12,
    marginTop: spacing.xs,
    marginBottom: spacing.sm,
  },
  row: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  halfInput: {
    flex: 1,
  },
  radioItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  radioContent: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  radioDescription: {
    opacity: 0.7,
    marginTop: spacing.xs,
  },
  divider: {
    marginVertical: spacing.sm,
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
  itemRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.sm,
    paddingVertical: spacing.xs,
  },
  itemInfo: {
    flex: 1,
    marginRight: spacing.md,
  },
  itemName: {
    fontWeight: '500',
    marginBottom: spacing.xs,
  },
  itemVariant: {
    opacity: 0.7,
    marginBottom: spacing.xs,
  },
  itemQuantity: {
    opacity: 0.8,
    fontSize: 12,
  },
  itemPrice: {
    fontWeight: '600',
  },
  bottomSpacer: {
    height: spacing.xl,
  },
  buttonContainer: {
    padding: spacing.md,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  placeOrderButton: {
    borderRadius: 8,
  },
  placeOrderButtonContent: {
    paddingVertical: spacing.sm,
  },
  paymentOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  paymentOptionContent: {
    marginLeft: spacing.md,
    flex: 1,
  },
  paymentOptionTitle: {
    marginBottom: spacing.xs,
  },
  paymentOptionDescription: {
    opacity: 0.7,
  },
  codNote: {
    marginTop: spacing.md,
    padding: spacing.sm,
    backgroundColor: '#FFF3E0',
    borderRadius: 8,
    borderLeftWidth: 3,
    borderLeftColor: '#FF9800',
  },
  codNoteText: {
    color: '#E65100',
  },
});
