import React from 'react';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useTheme } from 'react-native-paper';
import { sanctuaryColors, typography, spacing } from '@/theme';
import { RootStackParamList, BottomTabParamList } from '@/types';

// Import screens (placeholders for now - will be created in next prompts)
import HomeScreen from '@/screens/Home/HomeScreen';
import ShopScreen from '@/screens/Shop/ShopScreen';
import BooksScreen from '@/screens/Books/BooksScreen';
import VideosScreen from '@/screens/Videos/VideosScreen';
import MusicScreen from '@/screens/Music/MusicScreen';
import ProfileScreen from '@/screens/Profile/ProfileScreen';
import MoreScreen from '@/screens/More/MoreScreen';
import ProductDetailScreen from '@/screens/Shop/ProductDetailScreen';
import BookDetailScreen from '@/screens/Books/BookDetailScreen';
import VideoDetailScreen from '@/screens/Videos/VideoDetailScreen';
import MusicDetailScreen from '@/screens/Music/MusicDetailScreen';
import CartScreen from '@/screens/Cart/CartScreen';
import CheckoutScreen from '@/screens/Cart/CheckoutScreen';
import BuyNowCheckoutScreen from '@/screens/Cart/BuyNowCheckoutScreen';
import OrderConfirmationScreen from '@/screens/Cart/OrderConfirmationScreen';
import AddressScreen from '@/screens/Checkout/AddressScreen';
import OrderSummaryScreen from '@/screens/Checkout/OrderSummaryScreen';
import PaymentMethodScreen from '@/screens/Checkout/PaymentMethodScreen';
import SearchScreen from '@/screens/Search/SearchScreen';
import CategoryScreen from '@/screens/Category/CategoryScreen';
import AuthScreen from '@/screens/Auth/AuthScreen';
import WishlistScreen from '@/screens/Profile/WishlistScreen';
import OrdersScreen from '@/screens/Profile/OrdersScreen';
import DownloadsScreen from '@/screens/Profile/DownloadsScreen';
import SettingsScreen from '@/screens/Profile/SettingsScreen';
import PDFReaderScreen from '@/screens/Books/PDFReaderScreen';
import VideoPlayerScreen from '@/screens/Videos/VideoPlayerScreen';
import MusicPlayerScreen from '@/screens/Music/MusicPlayerScreen';

const Stack = createStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator<BottomTabParamList>();

// Bottom Tab Navigator
function BottomTabNavigator() {
  const theme = useTheme();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ color, size }) => {
          let iconName: keyof typeof MaterialCommunityIcons.glyphMap = 'home';

          switch (route.name) {
            case 'Home':
              iconName = 'home';
              break;
            case 'Shop':
              iconName = 'shopping';
              break;
            case 'Books':
              iconName = 'book-open-variant';
              break;
            case 'Videos':
              iconName = 'play-circle';
              break;
            case 'Music':
              iconName = 'music';
              break;
            case 'Profile':
              iconName = 'account';
              break;
            case 'More':
              iconName = 'dots-horizontal-circle-outline';
              break;
          }

          return <MaterialCommunityIcons name={iconName} size={size + 4} color={color} />;
        },
        tabBarActiveTintColor: sanctuaryColors.deepGold,
        tabBarInactiveTintColor: sanctuaryColors.warmGray,
        tabBarStyle: {
          backgroundColor: sanctuaryColors.lotusWhite,
          borderTopColor: sanctuaryColors.mildBeige,
          borderTopWidth: 1,
          paddingBottom: spacing.sm,
          paddingTop: spacing.sm,
          height: 68,
        },
        tabBarLabelStyle: {
          ...typography.caption,
          fontSize: 12,
        },
        headerShown: false,
      })}
    >
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Shop" component={ShopScreen} />
      <Tab.Screen name="Books" component={BooksScreen} />
      <Tab.Screen name="More" component={MoreScreen} />
      <Tab.Screen
        name="Videos"
        component={VideosScreen}
        options={{ tabBarButton: () => null }}
      />
      <Tab.Screen
        name="Music"
        component={MusicScreen}
        options={{ tabBarButton: () => null }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{ tabBarButton: () => null }}
      />
    </Tab.Navigator>
  );
}

// Root Stack Navigator
export default function RootNavigator() {
  const theme = useTheme();

  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerStyle: {
            backgroundColor: theme.colors.primary,
          },
          headerTintColor: theme.colors.onPrimary,
          headerTitleStyle: {
            fontWeight: 'bold',
          },
        }}
      >
        <Stack.Screen
          name="Main"
          component={BottomTabNavigator}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="ProductDetail"
          component={ProductDetailScreen}
          options={{ title: 'Product Details' }}
        />
        <Stack.Screen
          name="BookDetail"
          component={BookDetailScreen}
          options={{ title: 'Book Details' }}
        />
        <Stack.Screen
          name="VideoDetail"
          component={VideoDetailScreen}
          options={{ title: 'Video Details' }}
        />
        <Stack.Screen
          name="MusicDetail"
          component={MusicDetailScreen}
          options={{ title: 'Music Details' }}
        />
        <Stack.Screen name="Cart" component={CartScreen} options={{ title: 'Shopping Cart' }} />
        {/* New Checkout Flow */}
        <Stack.Screen
          name="CheckoutAddress"
          component={AddressScreen}
          options={{ title: 'Select Address' }}
        />
        <Stack.Screen
          name="OrderSummary"
          component={OrderSummaryScreen}
          options={{ title: 'Order Summary' }}
        />
        <Stack.Screen
          name="PaymentMethod"
          component={PaymentMethodScreen}
          options={{ title: 'Payment Options' }}
        />

        {/* Legacy Checkout - keeping for reference if needed, but Cart will point to CheckoutAddress */}
        <Stack.Screen
          name="Checkout"
          component={CheckoutScreen}
          options={{ title: 'Checkout' }}
        />
        <Stack.Screen
          name="OrderConfirmation"
          component={OrderConfirmationScreen}
          options={{ title: 'Order Confirmation', headerLeft: () => null }}
        />
        <Stack.Screen name="Search" component={SearchScreen} options={{ title: 'Search' }} />
        <Stack.Screen
          name="Category"
          component={CategoryScreen}
          options={{ title: 'Category' }}
        />
        <Stack.Screen
          name="Auth"
          component={AuthScreen}
          options={{ title: 'Login / Sign Up', headerShown: false }}
        />
        <Stack.Screen
          name="Wishlist"
          component={WishlistScreen}
          options={{ title: 'My Wishlist' }}
        />
        <Stack.Screen name="Orders" component={OrdersScreen} options={{ title: 'My Orders' }} />
        <Stack.Screen
          name="Downloads"
          component={DownloadsScreen}
          options={{ title: 'Downloads' }}
        />
        <Stack.Screen
          name="Settings"
          component={SettingsScreen}
          options={{ title: 'Settings' }}
        />
        <Stack.Screen
          name="PDFReader"
          component={PDFReaderScreen}
          options={{ title: 'Read Book', headerShown: false }}
        />
        <Stack.Screen
          name="VideoPlayer"
          component={VideoPlayerScreen}
          options={{ title: 'Watch Video', headerShown: false }}
        />
        <Stack.Screen
          name="MusicPlayer"
          component={MusicPlayerScreen}
          options={{ title: 'Now Playing', headerShown: false }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
