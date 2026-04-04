import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Appbar } from 'react-native-paper';
import EmptyState from '@/components/common/EmptyState';

export default function VideosScreen() {
  return (
    <View style={styles.container}>
      <Appbar.Header elevated>
        <Appbar.Content title="Videos" titleStyle={styles.title} />
        <Appbar.Action icon="magnify" onPress={() => {}} />
      </Appbar.Header>
      
      <EmptyState
        icon="play-circle"
        title="Videos Coming Soon"
        message="Watch meditation tutorials, yoga sessions, and spiritual guidance videos. Coming soon!"
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
