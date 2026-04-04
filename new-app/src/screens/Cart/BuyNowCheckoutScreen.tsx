import React, { useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, KeyboardAvoidingView, Platform, Image } from 'react-native';
import { Appbar, Text, TextInput, Button, RadioButton, Card, Divider, useTheme, IconButton, Snackbar } from 'react-native-paper';
import { useAppSelector, useAppDispatch } from '@/hooks/useTypedSelector';
import { formatCurrency } from '@/utils/format';
import { spacing } from '@/theme';
import { APP_CONFIG, API_CONFIG, ERROR_MESSAGES, SUCCESS_MESSAGES } from '@/constants';
import { updateBuyNowQuantity, clearBuyNow } from '@/store/slices/buyNowSlice';
import { validateQuantityChange } from '@/utils/quantity';
import type { RootState } from '@/store';
import type { RazorpayOptions } from '@/types';
import { OrderStatus, PaymentStatus } from '@/types';
import RealRazorpayPayment from '@/components/payments/RealRazorpayPayment';
import { createRazorpayOrder, verifyRazorpayPayment, createCodOrder, type CreateRazorpayOrderData, type CreateRazorpayOrderPayload } from '@/services/payments';
import { addOrder } from '@/store/slices/userSlice';

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

export default function BuyNowCheckoutScreen({ navigation }: any) {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const buyNow = useAppSelector((state: RootState) => state.buyNow);
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

  // Clear buy now data when component unmounts
  useEffect(() => {
    return () => {
      // Don't clear on navigation, only on unmount
    };
  }, []);

  // Redirect if no buy now item
  useEffect(() => {
    if (!buyNow.item) {
      navigation.goBack();
    }
  }, [buyNow.item, navigation]);

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

  const handleQuantityChange = (delta: number) => {
    if (!buyNow.item) return;

    const validation = validateQuantityChange(
      buyNow.item.quantity,
      delta,
      buyNow.item.product,
      buyNow.item.variant?.id
    );

    if (validation.isValid) {
      dispatch(updateBuyNowQuantity(buyNow.item.quantity + delta));
    }
  };

  const validateForm = (): boolean => {
    const newErrors: Partial<CheckoutForm> = {};

    if (!form.name.trim()) newErrors.name = 'Name is required';
    if (!form.email.trim()) newErrors.email = 'Email is required';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) newErrors.email = 'Invalid email';
    if (!form.phone.trim()) newErrors.phone = 'Phone is required';
    if (!/^\d{10}$/.test(form.phone)) newErrors.phone = 'Invalid phone number';
    if (!form.address.trim()) newErrors.address = 'Address is required';
    if (!form.city.trim()) newErrors.city = 'City is required';
    if (!form.state.trim()) newErrors.state = 'State is required';
    if (!form.pincode.trim()) newErrors.pincode = 'Pincode is required';
    if (!/^\d{6}$/.test(form.pincode)) newErrors.pincode = 'Invalid pincode';

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handlePlaceOrder = async () => {
    if (!validateForm() || !buyNow.item) return;

    const item = buyNow.item;

    const payload: CreateRazorpayOrderPayload = {
      checkoutType: 'buy_now' as const,
      saleorChannel: API_CONFIG.SALEOR_CHANNEL,
      items: [
        {
          productId: item.product.id,
          variantId: item.variant?.id,
          quantity: item.quantity,
          unitPrice: item.price,
          totalPrice: item.price * item.quantity,
        },
      ],
      amounts: {
        subtotal: buyNow.subtotal,
        tax: buyNow.tax,
        shipping: buyNow.shipping,
        discount: 0,
        total: buyNow.total,
        currency: buyNow.currency,
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

    console.log('Payment response:', response);
    console.log('Response success:', response.success);
    console.log('Response data:', response.data);
    console.log('Response error:', response.error);

    if (!response.success || !response.data) {
      const message = response.error?.message || ERROR_MESSAGES.SERVER_ERROR;
      console.log('Showing error message:', message);
      showSnackbar(message);
      return;
    }

    const data = response.data;
    setCurrentOrderMeta(data);
    console.log('Setting payment options:', data);

    // For COD, directly navigate to confirmation without payment modal
    if ((form.paymentMethod as 'razorpay' | 'cod') === 'cod') {
      // Create order for COD
      const order = {
        id: data.saleorOrderId,
        orderNumber: data.saleorOrderNumber,
        user: user!,
        items: [
          {
            id: item.id,
            product: item.product,
            variant: item.variant,
            quantity: item.quantity,
            price: item.price,
            total: item.price * item.quantity,
          },
        ],
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
        subtotal: buyNow.subtotal,
        tax: buyNow.tax,
        shipping: buyNow.shipping,
        discount: 0,
        total: buyNow.total,
        currency: buyNow.currency,
        status: OrderStatus.PENDING,
        paymentStatus: PaymentStatus.PENDING,
        paymentMethod: 'COD',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      dispatch(addOrder(order));
      dispatch(clearBuyNow());
      showSnackbar(SUCCESS_MESSAGES.ORDER_PLACED);
      navigation.navigate('OrderConfirmation', { order });
      return;
    }

    // For Razorpay, proceed with payment modal
    console.log('Opening payment modal...');
    try {
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

      console.log('Payment options created successfully:', options);
      setPaymentOptions(options);
      console.log('Payment options set, setting modal visible to true');
      setPaymentModalVisible(true);
      console.log('Modal visibility set to true');
    } catch (error) {
      console.log('Error creating payment options:', error);
      showSnackbar('Failed to initialize payment options');
    }
  };

  const handlePaymentSuccess = async (payment: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    razorpaySignature: string;
  }) => {
    console.log('handlePaymentSuccess called with:', payment);
    
    if (!currentOrderMeta) {
      console.log('ERROR: No currentOrderMeta');
      showSnackbar(ERROR_MESSAGES.PAYMENT_FAILED);
      return;
    }

    console.log('Setting payment modal visible to false');
    setPaymentModalVisible(false);
    console.log('Setting isPlacingOrder to true');
    setIsPlacingOrder(true);

    // Check if this is a mock payment (test mode)
    const isMockPayment = payment.razorpayPaymentId.startsWith('pay_mock_');
    console.log('Is mock payment:', isMockPayment);
    
    if (isMockPayment) {
      // For mock payments, skip verification and create order directly
      console.log('Mock payment detected, skipping verification');
      
      try {
        const order = {
          id: currentOrderMeta.saleorOrderId,
          orderNumber: currentOrderMeta.saleorOrderNumber,
          user: user!,
          items: [
            {
              id: item!.id,
              product: item!.product,
              variant: item!.variant,
              quantity: item!.quantity,
              price: item!.price,
              total: item!.price * item!.quantity,
            },
          ],
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
          subtotal: buyNow.subtotal,
          tax: buyNow.tax,
          shipping: buyNow.shipping,
          discount: 0,
          total: buyNow.total,
          currency: buyNow.currency,
          status: OrderStatus.PENDING,
          paymentStatus: PaymentStatus.PENDING,
          paymentMethod: 'ONLINE',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };

        console.log('Created order object:', order);
        console.log('Setting isPlacingOrder to false');
        setIsPlacingOrder(false);
        console.log('Dispatching clearBuyNow');
        dispatch(clearBuyNow());
        console.log('Dispatching addOrder');
        dispatch(addOrder(order));
        console.log('Showing success snackbar');
        showSnackbar(SUCCESS_MESSAGES.ORDER_PLACED);
        console.log('Navigating to OrderConfirmation');
        navigation.navigate('OrderConfirmation', { order });
        console.log('Navigation completed');
      } catch (error) {
        console.error('Error in mock payment handling:', error);
        setIsPlacingOrder(false);
        showSnackbar('Error processing payment');
      }
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
    dispatch(clearBuyNow());
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

  if (!buyNow.item) {
    return null;
  }

  const item = buyNow.item;

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.BackAction onPress={() => navigation.goBack()} />
        <Appbar.Content title="Buy Now - Checkout" />
      </Appbar.Header>

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.container}
      >
        <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
          
          {/* Product Summary */}
          <Card style={styles.card}>
            <Card.Content>
              <Text variant="titleLarge" style={styles.sectionTitle}>
                Product Details
              </Text>
              <Divider style={styles.divider} />
              
              <View style={styles.productRow}>
                <Image
                  source={{ 
                    uri: item.product.images[0]?.url || 'https://via.placeholder.com/80x80?text=Product'
                  }}
                  style={styles.productImage}
                  resizeMode="cover"
                />
                <View style={styles.productInfo}>
                  <Text variant="titleMedium" numberOfLines={2} style={styles.productName}>
                    {item.product.name}
                  </Text>
                  {item.variant && (
                    <Text variant="bodySmall" style={styles.productVariant}>
                      {item.variant.name}
                    </Text>
                  )}
                  <Text variant="bodyMedium" style={[styles.productPrice, { color: theme.colors.primary }]}>
                    {formatCurrency(item.price, item.currency)} each
                  </Text>
                </View>
              </View>

              {/* Quantity Controls */}
              <View style={styles.quantitySection}>
                <Text variant="bodyMedium" style={styles.quantityLabel}>Quantity:</Text>
                <View style={styles.quantityControls}>
                  <IconButton
                    icon="minus"
                    size={20}
                    onPress={() => handleQuantityChange(-1)}
                    disabled={item.quantity <= 1}
                    style={styles.quantityButton}
                  />
                  <Text variant="titleMedium" style={styles.quantityText}>
                    {item.quantity}
                  </Text>
                  <IconButton
                    icon="plus"
                    size={20}
                    onPress={() => handleQuantityChange(1)}
                    disabled={item.quantity >= 10}
                    style={styles.quantityButton}
                  />
                </View>
                <Text variant="bodyLarge" style={[styles.totalPrice, { color: theme.colors.primary }]}>
                  {formatCurrency(item.price * item.quantity, item.currency)}
                </Text>
              </View>
            </Card.Content>
          </Card>

          {/* Shipping Address */}
          <Card style={styles.card}>
            <Card.Content>
              <Text variant="titleLarge" style={styles.sectionTitle}>
                Shipping Address
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

              <View style={styles.summaryRow}>
                <Text variant="bodyLarge">Subtotal ({item.quantity} item{item.quantity > 1 ? 's' : ''})</Text>
                <Text variant="bodyLarge">{formatCurrency(buyNow.subtotal, buyNow.currency)}</Text>
              </View>

              <View style={styles.summaryRow}>
                <Text variant="bodyLarge">Tax (18% GST)</Text>
                <Text variant="bodyLarge">{formatCurrency(buyNow.tax, buyNow.currency)}</Text>
              </View>

              <View style={styles.summaryRow}>
                <Text variant="bodyLarge">Shipping</Text>
                {buyNow.shipping === 0 ? (
                  <Text variant="bodyLarge" style={styles.freeShipping}>FREE</Text>
                ) : (
                  <Text variant="bodyLarge">{formatCurrency(buyNow.shipping, buyNow.currency)}</Text>
                )}
              </View>

              <Divider style={styles.divider} />

              <View style={styles.totalRow}>
                <Text variant="titleLarge" style={styles.totalLabel}>
                  Total Amount
                </Text>
                <Text variant="titleLarge" style={[styles.totalAmount, { color: theme.colors.primary }]}>
                  {formatCurrency(buyNow.total, buyNow.currency)}
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
            onPress={handlePlaceOrder}
            loading={isPlacingOrder}
            disabled={isPlacingOrder || !buyNow.item}
            style={styles.placeOrderButton}
            contentStyle={styles.placeOrderButtonContent}
          >
            Place Order - {formatCurrency(buyNow.total, buyNow.currency)}
          </Button>
        </View>
      </KeyboardAvoidingView>

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
  card: {
    margin: spacing.md,
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontWeight: 'bold',
    marginBottom: spacing.md,
  },
  productRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: spacing.md,
  },
  productImage: {
    width: 80,
    height: 80,
    borderRadius: 8,
    marginRight: spacing.md,
  },
  productInfo: {
    flex: 1,
  },
  productName: {
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  productVariant: {
    opacity: 0.7,
    marginBottom: spacing.xs,
  },
  productPrice: {
    fontWeight: '600',
  },
  quantitySection: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  quantityLabel: {
    fontWeight: '600',
  },
  quantityControls: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
  },
  quantityButton: {
    margin: 0,
  },
  quantityText: {
    minWidth: 40,
    textAlign: 'center',
    fontWeight: '600',
  },
  totalPrice: {
    fontWeight: 'bold',
    fontSize: 16,
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
