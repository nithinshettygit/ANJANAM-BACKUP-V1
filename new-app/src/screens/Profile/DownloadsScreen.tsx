import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar } from 'react-native-paper';
import EmptyState from '@/components/common/EmptyState';

export default function DownloadsScreen() {
  return (
    <View style={styles.container}>
      <Appbar.Header><Appbar.Content title="Downloads" /></Appbar.Header>
      <EmptyState icon="download" title="No downloads" message="Your downloaded content will appear here." />
    </View>
  );
}

const styles = StyleSheet.create({ container: { flex: 1 } });
