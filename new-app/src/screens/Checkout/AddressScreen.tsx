import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Text, Button, RadioButton, Card, TextInput, useTheme, Divider, Appbar } from 'react-native-paper';
import { spacing } from '@/theme';
import { useAppSelector } from '@/hooks/useTypedSelector';
import { RootState } from '@/store';

// Mock data for saved addresses
const MOCK_ADDRESSES = [
  {
    id: '1',
    name: 'Nithin Shetty',
    phone: '9876543210',
    address: '123, Tech Park, Koramangala',
    city: 'Bengaluru',
    state: 'Karnataka',
    pincode: '560034',
    type: 'Home',
  },
  {
    id: '2',
    name: 'Nithin (Office)',
    phone: '9876543210',
    address: '456, HSR Layout, Sector 7',
    city: 'Bengaluru',
    state: 'Karnataka',
    pincode: '560102',
    type: 'Work',
  },
];

export default function AddressScreen({ navigation, route }: any) {
  const theme = useTheme();
  const buyNowItem = useAppSelector((state: RootState) => state.buyNow.item);
  const buyNowLineParam = route.params?.buyNowLine;
  const routeFlow = route.params?.flow ?? 'cart';
  const flow =
    buyNowLineParam || buyNowItem ? 'buy_now' : routeFlow;
  const user = useAppSelector((state: RootState) => state.auth.user);

  // For guests, start with empty addresses. For logged in (mock), show mocks.
  const [addresses, setAddresses] = useState<any[]>(user ? MOCK_ADDRESSES : []);
  const [selectedAddressId, setSelectedAddressId] = useState<string>(user ? MOCK_ADDRESSES[0].id : '');
  const [showAddForm, setShowAddForm] = useState(!user); // Default to form if guest

  // New Address Form State
  const [newAddress, setNewAddress] = useState({
    name: '',
    phone: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    type: 'Home',
  });

  const handleDeliverHere = () => {
    const selected = addresses.find(addr => addr.id === selectedAddressId);
    if (selected) {
      navigation.navigate('OrderSummary', {
        address: selected,
        flow,
        ...(buyNowLineParam ? { buyNowLine: buyNowLineParam } : {}),
      });
    }
  };

  const handleSaveNewAddress = () => {
    // Create a new address object
    const newAddrObj = {
      id: Date.now().toString(),
      ...newAddress,
      type: newAddress.type || 'Home'
    };

    // Add to local list and select it
    setAddresses([newAddrObj, ...addresses]);
    setSelectedAddressId(newAddrObj.id);

    // Switch back to list view
    setShowAddForm(false);
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {!showAddForm ? (
          <>
            <Text variant="titleMedium" style={styles.headerTitle}>Select Delivery Address</Text>

            <RadioButton.Group onValueChange={value => setSelectedAddressId(value)} value={selectedAddressId}>
              {addresses.map((addr) => (
                <Card key={addr.id} style={[styles.card, selectedAddressId === addr.id && styles.selectedCard]} onPress={() => setSelectedAddressId(addr.id)}>
                  <Card.Content style={styles.cardContent}>
                    <View style={styles.radioContainer}>
                      <RadioButton value={addr.id} />
                    </View>
                    <View style={styles.addressDetails}>
                      <View style={styles.nameRow}>
                        <Text variant="titleMedium" style={styles.name}>{addr.name}</Text>
                        <View style={styles.tag}><Text style={styles.tagText}>{addr.type}</Text></View>
                      </View>
                      <Text variant="bodyMedium" style={styles.addressText}>
                        {addr.address}, {addr.city}, {addr.state} - {addr.pincode}
                      </Text>
                      <Text variant="bodyMedium" style={styles.phoneText}>Phone: {addr.phone}</Text>

                      {selectedAddressId === addr.id && (
                        <Button mode="contained" onPress={handleDeliverHere} style={styles.deliverButton}>
                          Deliver Here
                        </Button>
                      )}
                    </View>
                  </Card.Content>
                </Card>
              ))}
            </RadioButton.Group>

            <Button mode="outlined" icon="plus" onPress={() => setShowAddForm(true)} style={styles.addButton}>
              Add New Address
            </Button>
          </>
        ) : (
          <View style={styles.formContainer}>
            <Text variant="titleLarge" style={styles.formHeader}>Add New Address</Text>
            <TextInput label="Full Name" value={newAddress.name} onChangeText={t => setNewAddress({ ...newAddress, name: t })} style={styles.input} mode="outlined" />
            <TextInput label="Phone Number" value={newAddress.phone} onChangeText={t => setNewAddress({ ...newAddress, phone: t })} style={styles.input} mode="outlined" keyboardType="phone-pad" />
            <TextInput label="Pincode" value={newAddress.pincode} onChangeText={t => setNewAddress({ ...newAddress, pincode: t })} style={styles.input} mode="outlined" keyboardType="number-pad" />
            <TextInput label="City" value={newAddress.city} onChangeText={t => setNewAddress({ ...newAddress, city: t })} style={styles.input} mode="outlined" />
            <TextInput label="State" value={newAddress.state} onChangeText={t => setNewAddress({ ...newAddress, state: t })} style={styles.input} mode="outlined" />
            <TextInput label="Address (House No, Building, Street)" value={newAddress.address} onChangeText={t => setNewAddress({ ...newAddress, address: t })} style={styles.input} mode="outlined" multiline />

            <View style={styles.formActions}>
              <Button onPress={() => setShowAddForm(false)} style={styles.cancelButton}>Cancel</Button>
              <Button mode="contained" onPress={handleSaveNewAddress} style={styles.saveButton}>Save Address</Button>
            </View>
          </View>
        )}
      </ScrollView>
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
  },
  headerTitle: {
    marginBottom: spacing.md,
    fontWeight: 'bold',
    color: '#666',
  },
  card: {
    marginBottom: spacing.md,
    borderColor: 'transparent',
    borderWidth: 1,
  },
  selectedCard: {
    borderColor: '#2874F0', // Flipkart blue-ish
    backgroundColor: '#F0F8FF',
  },
  cardContent: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  radioContainer: {
    marginRight: spacing.sm,
    marginTop: -4,
  },
  addressDetails: {
    flex: 1,
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  name: {
    fontWeight: 'bold',
    marginRight: spacing.sm,
  },
  tag: {
    backgroundColor: '#E0E0E0',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  tagText: {
    fontSize: 10,
    color: '#333',
  },
  addressText: {
    marginBottom: spacing.xs,
    color: '#333',
  },
  phoneText: {
    marginBottom: spacing.md,
    color: '#666',
  },
  deliverButton: {
    marginTop: spacing.sm,
  },
  addButton: {
    marginTop: spacing.sm,
    borderColor: '#2874F0',
  },
  formContainer: {
    backgroundColor: 'white',
    padding: spacing.md,
    borderRadius: 8,
  },
  formHeader: {
    marginBottom: spacing.md,
  },
  input: {
    marginBottom: spacing.sm,
    backgroundColor: 'white',
  },
  formActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: spacing.md,
  },
  cancelButton: {
    marginRight: spacing.sm,
  },
  saveButton: {

  },
});
