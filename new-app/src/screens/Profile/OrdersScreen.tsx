import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar } from 'react-native-paper';
import EmptyState from '@/components/common/EmptyState';

export default function OrdersScreen() {
  return (
    <View style={styles.container}>
      <Appbar.Header><Appbar.Content title="My Orders" /></Appbar.Header>
      <EmptyState icon="package-variant" title="No orders yet" message="Your order history will appear here." />
    </View>
  );
}

const styles = StyleSheet.create({ container: { flex: 1 } });
