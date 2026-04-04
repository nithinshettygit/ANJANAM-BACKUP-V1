import React from 'react';
import { View, StyleSheet, ScrollView } from 'react-native';
import { Text, Button, Card, Divider, useTheme } from 'react-native-paper';
import { useAppSelector } from '@/hooks/useTypedSelector';
import { formatCurrency } from '@/utils/format';
import { fixImageUrl } from '@/utils/url';
import { spacing } from '@/theme';
import type { RootState } from '@/store';
import { buildBuyNowCartSummary } from '@/utils/checkoutTotals';

export default function OrderSummaryScreen({ navigation, route }: any) {
  const theme = useTheme();
  const cart = useAppSelector((state: RootState) => state.cart.cart);
  const buyNow = useAppSelector((state: RootState) => state.buyNow);

  const { address, flow: routeFlow = 'cart', buyNowLine: buyNowLineParam } = route.params || {};
  const isBuyNow = Boolean(buyNowLineParam) || Boolean(buyNow.item);
  const flow = isBuyNow ? 'buy_now' : routeFlow;

  const data = buyNowLineParam
    ? buildBuyNowCartSummary(buyNowLineParam)
    : buyNow.item
      ? {
          items: [
            {
              id: buyNow.item.id,
              product: buyNow.item.product,
              quantity: buyNow.item.quantity,
              variant: buyNow.item.variant,
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

  const handleContinue = () => {
    navigation.navigate('PaymentMethod', {
      address,
      flow,
      ...(buyNowLineParam ? { buyNowLine: buyNowLineParam } : {}),
    });
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Address Summary */}
        {address && (
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.headerRow}>
                <Text variant="titleMedium" style={styles.sectionTitle}>Deliver to:</Text>
                <Button mode="text" compact onPress={() => navigation.goBack()}>Change</Button>
              </View>
              <Text variant="labelLarge" style={styles.name}>{address.name}</Text>
              <Text variant="bodyMedium" style={styles.address}>
                {address.address}, {address.city}, {address.state} - {address.pincode}
              </Text>
              <Text variant="bodyMedium" style={styles.phone}>{address.phone}</Text>
            </Card.Content>
          </Card>
        )}

        {/* Items Summary */}
        <Card style={styles.card}>
          <Card.Content>
            <Text variant="titleMedium" style={styles.sectionTitle}>Price Details</Text>
            <Divider style={styles.divider} />

            <View style={styles.row}>
              <Text>Price ({data.items.length} items)</Text>
              <Text>{formatCurrency(data.subtotal, 'INR')}</Text>
            </View>
            <View style={styles.row}>
              <Text>Tax</Text>
              <Text>{formatCurrency(data.tax, 'INR')}</Text>
            </View>
            <View style={styles.row}>
              <Text>Delivery Charges</Text>
              <Text style={{ color: data.shipping === 0 ? 'green' : 'black' }}>
                {data.shipping === 0 ? 'FREE' : formatCurrency(data.shipping, 'INR')}
              </Text>
            </View>
            <Divider style={styles.divider} />
            <View style={styles.totalRow}>
              <Text variant="titleMedium" style={{ fontWeight: 'bold' }}>Total Amount</Text>
              <Text variant="titleMedium" style={{ fontWeight: 'bold' }}>{formatCurrency(data.total, 'INR')}</Text>
            </View>
          </Card.Content>
        </Card>

        {/* Item List (Simplified) */}
        <Text variant="titleMedium" style={styles.itemsHeader}>Items</Text>
        {data.items.map((item: any) => (
          <Card key={item.id} style={styles.itemCard}>
            <Card.Content style={styles.itemContent}>
              <View style={styles.itemDetails}>
                <Text variant="bodyLarge" style={styles.itemName}>{item.product.name}</Text>
                <Text variant="bodySmall">Qty: {item.quantity}</Text>
                <Text variant="labelLarge" style={styles.itemPrice}>
                  {formatCurrency((item.variant?.price || item.product.price || item.price) * item.quantity, 'INR')}
                </Text>
              </View>
            </Card.Content>
          </Card>
        ))}

      </ScrollView>

      <View style={styles.footer}>
        <View style={styles.footerTotal}>
          <Text variant="labelLarge">{formatCurrency(data.total, 'INR')}</Text>
          <Text variant="bodySmall" style={styles.viewDetailsText}>Total Amount</Text>
        </View>
        <Button mode="contained" onPress={handleContinue} style={styles.continueButton}>
          Continue
        </Button>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  scrollContent: {
    padding: spacing.md,
    paddingBottom: 80,
  },
  card: {
    marginBottom: spacing.md,
    backgroundColor: 'white',
    borderRadius: 4,
  },
  sectionTitle: {
    fontWeight: 'bold',
    marginBottom: spacing.xs,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  name: {
    fontWeight: '600',
  },
  address: {
    color: '#666',
    marginTop: 2,
  },
  phone: {
    color: '#666',
    marginTop: 2,
  },
  divider: {
    marginVertical: spacing.sm,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.xs,
  },
  itemsHeader: {
    marginBottom: spacing.sm,
    marginLeft: spacing.xs,
    color: '#666',
  },
  itemCard: {
    marginBottom: spacing.sm,
    borderRadius: 4,
  },
  itemContent: {
    paddingVertical: spacing.sm,
  },
  itemDetails: {},
  itemName: {
    fontWeight: '500',
  },
  itemPrice: {
    marginTop: spacing.xs,
  },
  footer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'white',
    flexDirection: 'row',
    padding: spacing.md,
    elevation: 8,
    alignItems: 'center',
  },
  footerTotal: {
    flex: 1,
  },
  viewDetailsText: {
    color: '#2874F0',
  },
  continueButton: {
    flex: 1,
    backgroundColor: '#FB641B', // Flipkart orange
    borderRadius: 2,
  },
});
