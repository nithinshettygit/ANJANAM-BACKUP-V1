import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar } from 'react-native-paper';
import EmptyState from '@/components/common/EmptyState';

export default function MusicScreen() {
  return (
    <View style={styles.container}>
      <Appbar.Header elevated>
        <Appbar.Content title="Music" titleStyle={styles.title} />
        <Appbar.Action icon="magnify" onPress={() => {}} />
      </Appbar.Header>
      
      <EmptyState
        icon="music"
        title="Music Coming Soon"
        message="Listen to meditation music, mantras, and spiritual soundscapes. Coming soon!"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  title: {
    fontWeight: 'bold',
  },
});
