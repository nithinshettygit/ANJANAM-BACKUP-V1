import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar, Text } from 'react-native-paper';

export default function AuthScreen() {
  return (
    <View style={styles.container}>
      <Appbar.Header><Appbar.Content title="Login / Sign Up" /></Appbar.Header>
      <View style={styles.content}><Text>Auth Screen - Coming Soon</Text></View>
    </View>
  );
}

const styles = StyleSheet.create({ container: { flex: 1 }, content: { flex: 1, justifyContent: 'center', alignItems: 'center' } });
