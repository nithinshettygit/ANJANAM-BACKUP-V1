// API Configuration
// IMPORTANT: Expo SDK 49+ requires EXPO_PUBLIC_ prefix for env variables
// Use your computer's local IP address instead of localhost for physical devices
const getApiUrl = () => {
  const envUrl = process.env.EXPO_PUBLIC_SALEOR_API_URL;
  if (envUrl) {
    // If localhost is used, warn the user
    if (envUrl.includes('localhost') || envUrl.includes('127.0.0.1')) {
      const message =
        '⚠️  WARNING: Using localhost will NOT work on physical devices!\n' +
        '   Update .env: EXPO_PUBLIC_SALEOR_API_URL=http://YOUR_IP:8000/graphql/\n' +
        '   Example: EXPO_PUBLIC_SALEOR_API_URL=http://192.168.1.3:8000/graphql/\n' +
        '4. Restart the development server with --clear flag:\n' +
        '   npx expo start --clear\n\n' +
        '--------------------------------------------------------------------------------\n';
      console.warn(message);
    }
    return envUrl;
  }
  // Default fallback to expected local backend URL if env var is missing
  console.log(
    '⚠️ API_CONFIG: EXPO_PUBLIC_SALEOR_API_URL not found in environment.\n' +
    '   Using fallback: http://192.168.1.3:8000/graphql/\n' +
    '   Make sure your backend is running at this address.'
  );
  return 'http://192.168.1.3:8000/graphql/';
};

const getPaymentServiceUrl = () => {
  const envUrl = process.env.EXPO_PUBLIC_PAYMENT_SERVICE_URL;
  if (envUrl) return envUrl;

  // Use the same IP as SALEOR_URL but with port 5000
  // valid for our current debugging session where we know it's 192.168.1.3
  return 'http://192.168.1.3:5000';
};

export const API_CONFIG = {
  SALEOR_URL: getApiUrl(),
  PAYMENT_SERVICE_URL: getPaymentServiceUrl(),
  SALEOR_CHANNEL: 'india-channel', // Updated to match your Saleor India Channel
  TIMEOUT: 30000,
  RETRY_ATTEMPTS: 3,
};

// Firebase Configuration
export const FIREBASE_CONFIG = {
  apiKey: process.env.FIREBASE_API_KEY || '',
  authDomain: process.env.FIREBASE_AUTH_DOMAIN || '',
  projectId: process.env.FIREBASE_PROJECT_ID || '',
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID || '',
  appId: process.env.FIREBASE_APP_ID || '',
};

// Razorpay Configuration
export const RAZORPAY_CONFIG = {
  KEY_ID: process.env.RAZORPAY_KEY_ID || '',
  KEY_SECRET: process.env.RAZORPAY_KEY_SECRET || '',
};

// YouTube Configuration
export const YOUTUBE_CONFIG = {
  API_KEY: process.env.YOUTUBE_API_KEY || '',
};

// App Configuration
export const APP_CONFIG = {
  APP_NAME: 'ANJANAM',
  APP_VERSION: '1.0.0',
  CURRENCY: 'INR',
  CURRENCY_SYMBOL: '₹',
  TAX_RATE: 0.18, // 18% GST
  SHIPPING_RATE: 50, // ₹50 flat shipping
  FREE_SHIPPING_THRESHOLD: 500, // Free shipping above ₹500
  DEFAULT_PAGE_SIZE: 20,
  MAX_CART_QUANTITY: 10,
  SUPPORTED_LANGUAGES: ['en', 'hi'],
  DEFAULT_LANGUAGE: 'en',
};

// Content Type Icons
export const CONTENT_ICONS = {
  product: 'shopping',
  book: 'book',
  video: 'play-circle',
  music: 'music',
  cart: 'shopping-cart',
  wishlist: 'heart',
  profile: 'account',
  search: 'magnify',
  filter: 'filter-variant',
  sort: 'sort',
  download: 'download',
  share: 'share-variant',
  notification: 'bell',
  settings: 'cog',
};

// Category Icons Mapping
export const CATEGORY_ICONS: Record<string, string> = {
  meditation: 'yoga',
  spirituality: 'lotus',
  wellness: 'heart-pulse',
  yoga: 'yoga',
  music: 'music',
  books: 'book-open-variant',
  courses: 'school',
  accessories: 'shopping',
};

// Order Status Colors
export const ORDER_STATUS_COLORS: Record<string, string> = {
  PENDING: '#FF9800',
  CONFIRMED: '#2196F3',
  PROCESSING: '#9C27B0',
  SHIPPED: '#3F51B5',
  DELIVERED: '#4CAF50',
  CANCELLED: '#F44336',
  REFUNDED: '#607D8B',
};

// Payment Status Colors
export const PAYMENT_STATUS_COLORS: Record<string, string> = {
  PENDING: '#FF9800',
  AUTHORIZED: '#2196F3',
  PAID: '#4CAF50',
  FAILED: '#F44336',
  REFUNDED: '#607D8B',
};

// Validation Rules
export const VALIDATION = {
  EMAIL_REGEX: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  PHONE_REGEX: /^[6-9]\d{9}$/,
  PINCODE_REGEX: /^\d{6}$/,
  MIN_PASSWORD_LENGTH: 8,
  MAX_CART_ITEMS: 50,
  MIN_ORDER_VALUE: 100,
};

// Image Placeholders
export const PLACEHOLDERS = {
  PRODUCT: 'https://via.placeholder.com/400x400?text=Product',
  BOOK: 'https://via.placeholder.com/300x450?text=Book',
  VIDEO: 'https://via.placeholder.com/640x360?text=Video',
  MUSIC: 'https://via.placeholder.com/400x400?text=Music',
  USER: 'https://via.placeholder.com/200x200?text=User',
};

// Animation Durations
export const ANIMATION = {
  FAST: 150,
  NORMAL: 300,
  SLOW: 500,
};

// Storage Keys
export const STORAGE_KEYS = {
  AUTH_TOKEN: '@anjanam/auth_token',
  USER_DATA: '@anjanam/user_data',
  CART: '@anjanam/cart',
  WISHLIST: '@anjanam/wishlist',
  THEME: '@anjanam/theme',
  LANGUAGE: '@anjanam/language',
  FCM_TOKEN: '@anjanam/fcm_token',
  FIRST_LAUNCH: '@anjanam/first_launch',
};

// Error Messages
export const ERROR_MESSAGES = {
  NETWORK_ERROR: 'Network error. Please check your internet connection.',
  SERVER_ERROR: 'Server error. Please try again later.',
  AUTHENTICATION_ERROR: 'Authentication failed. Please login again.',
  INVALID_CREDENTIALS: 'Invalid email or password.',
  REQUIRED_FIELD: 'This field is required.',
  INVALID_EMAIL: 'Please enter a valid email address.',
  INVALID_PHONE: 'Please enter a valid 10-digit phone number.',
  INVALID_PINCODE: 'Please enter a valid 6-digit pincode.',
  PASSWORD_TOO_SHORT: `Password must be at least ${VALIDATION.MIN_PASSWORD_LENGTH} characters.`,
  PAYMENT_FAILED: 'Payment failed. Please try again.',
  OUT_OF_STOCK: 'This item is out of stock.',
  CART_LIMIT_EXCEEDED: `Cannot add more than ${VALIDATION.MAX_CART_ITEMS} items to cart.`,
  MIN_ORDER_VALUE: `Minimum order value is ₹${VALIDATION.MIN_ORDER_VALUE}.`,
};

// Success Messages
export const SUCCESS_MESSAGES = {
  LOGIN_SUCCESS: 'Login successful!',
  SIGNUP_SUCCESS: 'Account created successfully!',
  LOGOUT_SUCCESS: 'Logged out successfully!',
  CART_ADDED: 'Added to cart!',
  CART_REMOVED: 'Removed from cart!',
  WISHLIST_ADDED: 'Added to wishlist!',
  WISHLIST_REMOVED: 'Removed from wishlist!',
  ORDER_PLACED: 'Order placed successfully!',
  PAYMENT_SUCCESS: 'Payment successful!',
  PROFILE_UPDATED: 'Profile updated successfully!',
  ADDRESS_SAVED: 'Address saved successfully!',
  DOWNLOAD_STARTED: 'Download started!',
  DOWNLOAD_COMPLETE: 'Download complete!',
};

// Tab Screen Names
export const TAB_SCREENS = {
  SHOP: 'Shop',
  BOOKS: 'Books',
  VIDEOS: 'Videos',
  MUSIC: 'Music',
  PROFILE: 'Profile',
};

// Content Types
export const CONTENT_TYPES = {
  PRODUCT: 'product',
  BOOK: 'book',
  VIDEO: 'video',
  MUSIC: 'music',
} as const;

// Razorpay Test Cards (for mock payment)
export const RAZORPAY_TEST_CARDS = {
  SUCCESS: {
    number: '4111111111111111',
    cvv: '123',
    expiry: '12/25',
  },
  FAILURE: {
    number: '4000000000000002',
    cvv: '123',
    expiry: '12/25',
  },
};

export { APP_LOGO } from './branding';
