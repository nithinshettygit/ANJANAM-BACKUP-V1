import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar, Text } from 'react-native-paper';

export default function SettingsScreen() {
  return (
    <View style={styles.container}>
      <Appbar.Header><Appbar.BackAction onPress={() => {}} /><Appbar.Content title="Settings" /></Appbar.Header>
      <View style={styles.content}><Text>Settings Screen</Text></View>
    </View>
  );
}

const styles = StyleSheet.create({ container: { flex: 1 }, content: { flex: 1, justifyContent: 'center', alignItems: 'center' } });
