import React from 'react';
import { View, StyleSheet, ScrollView } from 'react-native';
import { Appbar, List, Avatar, Text, Divider, useTheme } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '@/types';
import { useAppSelector } from '@/hooks/useTypedSelector';
import { spacing } from '@/theme';

type NavigationProp = StackNavigationProp<RootStackParamList>;

export default function ProfileScreen() {
  const navigation = useNavigation<NavigationProp>();
  const theme = useTheme();
  const user = useAppSelector((state) => state.auth.user);
  const isAuthenticated = useAppSelector((state) => state.auth.isAuthenticated);

  const handleAuthPress = () => {
    navigation.navigate('Auth');
  };

  const handleWishlistPress = () => {
    navigation.navigate('Wishlist');
  };

  const handleOrdersPress = () => {
    navigation.navigate('Orders');
  };

  const handleDownloadsPress = () => {
    navigation.navigate('Downloads');
  };

  const handleSettingsPress = () => {
    navigation.navigate('Settings');
  };

  return (
    <View style={styles.container}>
      <Appbar.Header elevated>
        <Appbar.Content title="Profile" titleStyle={styles.title} />
        <Appbar.Action icon="cog" onPress={handleSettingsPress} />
      </Appbar.Header>

      <ScrollView>
        {/* User Info */}
        <View style={[styles.userSection, { backgroundColor: theme.colors.primary }]}>
          <Avatar.Icon size={80} icon="account" style={styles.avatar} />
          {isAuthenticated && user ? (
            <>
              <Text variant="headlineSmall" style={styles.userName}>
                {user.displayName || 'User'}
              </Text>
              <Text variant="bodyMedium" style={styles.userEmail}>
                {user.email}
              </Text>
            </>
          ) : (
            <>
              <Text variant="headlineSmall" style={styles.userName}>
                Guest User
              </Text>
              <Text variant="bodyMedium" style={styles.userEmail}>
                Login to access all features
              </Text>
            </>
          )}
        </View>

        {/* Menu Items */}
        <View style={styles.menuContainer}>
          {!isAuthenticated && (
            <>
              <List.Item
                title="Login / Sign Up"
                description="Access your account"
                left={(props) => <List.Icon {...props} icon="login" />}
                onPress={handleAuthPress}
              />
              <Divider />
            </>
          )}

          <List.Item
            title="My Orders"
            description="Track and view your orders"
            left={(props) => <List.Icon {...props} icon="package-variant" />}
            onPress={handleOrdersPress}
          />
          <Divider />

          <List.Item
            title="Wishlist"
            description="Your saved items"
            left={(props) => <List.Icon {...props} icon="heart" />}
            onPress={handleWishlistPress}
          />
          <Divider />

          <List.Item
            title="Downloads"
            description="Your downloaded content"
            left={(props) => <List.Icon {...props} icon="download" />}
            onPress={handleDownloadsPress}
          />
          <Divider />

          <List.Section title="App Info">
            <List.Item
              title="About ANJANAM"
              left={(props) => <List.Icon {...props} icon="information" />}
              onPress={() => {}}
            />
            <List.Item
              title="Privacy Policy"
              left={(props) => <List.Icon {...props} icon="shield-check" />}
              onPress={() => {}}
            />
            <List.Item
              title="Terms & Conditions"
              left={(props) => <List.Icon {...props} icon="file-document" />}
              onPress={() => {}}
            />
            <List.Item
              title="Help & Support"
              left={(props) => <List.Icon {...props} icon="help-circle" />}
              onPress={() => {}}
            />
          </List.Section>

          {isAuthenticated && (
            <>
              <Divider />
              <List.Item
                title="Logout"
                description="Sign out from your account"
                left={(props) => <List.Icon {...props} icon="logout" color="#F44336" />}
                titleStyle={{ color: '#F44336' }}
                onPress={() => {}}
              />
            </>
          )}
        </View>

        {/* App Version */}
        <View style={styles.versionContainer}>
          <Text variant="bodySmall" style={styles.versionText}>
            Version 1.0.0
          </Text>
        </View>
      </ScrollView>
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
  userSection: {
    padding: spacing.xl,
    alignItems: 'center',
  },
  avatar: {
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
    marginBottom: spacing.md,
  },
  userName: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    marginBottom: spacing.xs,
  },
  userEmail: {
    color: 'rgba(255, 255, 255, 0.9)',
  },
  menuContainer: {
    marginTop: spacing.md,
  },
  versionContainer: {
    alignItems: 'center',
    padding: spacing.xl,
  },
  versionText: {
    opacity: 0.5,
  },
});
