// =============================================
// CORE TYPES
// =============================================

export interface User {
  id: string;
  email: string;
  displayName: string | null;
  photoURL: string | null;
  phoneNumber: string | null;
  emailVerified: boolean;
  createdAt: string;
}

export interface Address {
  id?: string;
  name: string;
  phone: string;
  email: string;
  addressLine1: string;
  addressLine2?: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
  isDefault?: boolean;
}

// =============================================
// E-COMMERCE TYPES
// =============================================

export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  currency: string;
  images: ProductImage[];
  category: Category;
  variants: ProductVariant[];
  inStock: boolean;
  stockQuantity: number;
  rating: number;
  reviewCount: number;
  attributes: ProductAttribute[];
  slug: string;
  createdAt: string;
  // UI helper props
  thumbnail?: ProductImage;
  originalPrice?: { amount: number; currency: string };
  discount?: number;
  reviews?: number;
}

export interface ProductImage {
  id: string;
  url: string;
  alt: string;
}

export interface ProductVariant {
  id: string;
  name: string;
  price: number;
  stockQuantity: number;
  inStock: boolean;
  attributes: Record<string, string>;
}

export interface ProductAttribute {
  id: string;
  name: string;
  value: string;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  description?: string;
  image?: string;
  parent?: Category | null;
  children?: Category[];
}

export interface CartItem {
  id: string;
  product: Product;
  quantity: number;
  variant?: ProductVariant;
  addedAt: string;
}

export interface Cart {
  items: CartItem[];
  subtotal: number;
  tax: number;
  shipping: number;
  discount: number;
  total: number;
  currency: string;
}

export interface Order {
  id: string;
  orderNumber: string;
  user: User;
  items: OrderItem[];
  shippingAddress: Address;
  billingAddress: Address;
  subtotal: number;
  tax: number;
  shipping: number;
  discount: number;
  total: number;
  currency: string;
  status: OrderStatus;
  paymentStatus: PaymentStatus;
  paymentMethod: string;
  trackingNumber?: string;
  createdAt: string;
  updatedAt: string;
}

export interface OrderItem {
  id: string;
  product: Product;
  variant?: ProductVariant;
  quantity: number;
  price: number;
  total: number;
}

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  PROCESSING = 'PROCESSING',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELLED = 'CANCELLED',
  REFUNDED = 'REFUNDED',
}

export enum PaymentStatus {
  PENDING = 'PENDING',
  AUTHORIZED = 'AUTHORIZED',
  PAID = 'PAID',
  FAILED = 'FAILED',
  REFUNDED = 'REFUNDED',
}

// =============================================
// DIGITAL CONTENT TYPES
// =============================================

export interface Book {
  id: string;
  title: string;
  author: string;
  description: string;
  coverImage: string;
  pdfUrl: string;
  category: Category;
  language: string;
  pages: number;
  publishedDate: string;
  isbn?: string;
  price: number;
  currency: string;
  rating: number;
  reviewCount: number;
  tags: string[];
  isPurchased?: boolean;
  isDownloaded?: boolean;
  previewPages?: number;
  createdAt: string;
}

export interface Video {
  id: string;
  title: string;
  description: string;
  thumbnailUrl: string;
  youtubeId: string;
  duration: number; // in seconds
  category: Category;
  instructor?: string;
  price: number;
  currency: string;
  isPaid: boolean;
  isPurchased?: boolean;
  rating: number;
  viewCount: number;
  tags: string[];
  createdAt: string;
  publishedDate: string;
}

export interface Music {
  id: string;
  title: string;
  artist: string;
  album?: string;
  description: string;
  coverImage: string;
  streamingUrl: string; // Spotify/YouTube Music URL
  streamingPlatform: 'spotify' | 'youtube_music';
  trackId: string; // Platform-specific track ID
  duration: number; // in seconds
  category: Category;
  genre: string;
  price: number;
  currency: string;
  isPaid: boolean;
  isPurchased?: boolean;
  rating: number;
  playCount: number;
  tags: string[];
  createdAt: string;
  releaseDate: string;
}

// =============================================
// USER CONTENT TYPES
// =============================================

export interface Wishlist {
  id: string;
  userId: string;
  items: WishlistItem[];
  createdAt: string;
  updatedAt: string;
}

export interface WishlistItem {
  id: string;
  type: 'product' | 'book' | 'video' | 'music';
  itemId: string;
  item: Product | Book | Video | Music;
  addedAt: string;
}

export interface UserHistory {
  id: string;
  userId: string;
  items: HistoryItem[];
}

export interface HistoryItem {
  id: string;
  type: 'product_view' | 'book_read' | 'video_watch' | 'music_listen' | 'search';
  itemId?: string;
  item?: Product | Book | Video | Music;
  query?: string;
  timestamp: string;
}

export interface Download {
  id: string;
  userId: string;
  bookId: string;
  book: Book;
  localPath: string;
  downloadedAt: string;
  fileSize: number;
}

export interface Playlist {
  id: string;
  userId: string;
  name: string;
  description?: string;
  type: 'video' | 'music';
  items: PlaylistItem[];
  coverImage?: string;
  isPublic: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface PlaylistItem {
  id: string;
  itemId: string;
  item: Video | Music;
  addedAt: string;
  order: number;
}

// =============================================
// SEARCH & FILTER TYPES
// =============================================

export interface SearchFilters {
  query?: string;
  category?: string;
  priceMin?: number;
  priceMax?: number;
  rating?: number;
  tags?: string[];
  sortBy?: 'relevance' | 'price_asc' | 'price_desc' | 'rating' | 'newest';
}

export interface SearchResult {
  type: 'product' | 'book' | 'video' | 'music';
  item: Product | Book | Video | Music;
  relevanceScore: number;
}

export interface PaginationInfo {
  page: number;
  pageSize: number;
  totalPages: number;
  totalItems: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: PaginationInfo;
}

// =============================================
// PAYMENT TYPES
// =============================================

export interface RazorpayOptions {
  key: string;
  amount: number;
  currency: string;
  name: string;
  description: string;
  order_id: string;
  prefill: {
    name: string;
    email: string;
    contact: string;
  };
  theme: {
    color: string;
  };
}

export interface PaymentResult {
  success: boolean;
  paymentId?: string;
  orderId?: string;
  signature?: string;
  error?: string;
}

// =============================================
// NOTIFICATION TYPES
// =============================================

export interface Notification {
  id: string;
  userId: string;
  title: string;
  body: string;
  type: 'order' | 'product' | 'content' | 'system';
  data?: Record<string, any>;
  isRead: boolean;
  createdAt: string;
}

// =============================================
// API RESPONSE TYPES
// =============================================

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: ApiError;
  message?: string;
}

export interface ApiError {
  code: string;
  message: string;
  field?: string;
  details?: Record<string, any>;
}

// =============================================
// NAVIGATION TYPES
// =============================================

/** Single SKU for buy-now; passed through checkout stack so it cannot be confused with full cart. */
export type BuyNowLineParam = {
  product: Product;
  variant?: ProductVariant;
  quantity: number;
};

export type RootStackParamList = {
  Main: undefined;
  ProductDetail: { productId: string };
  BookDetail: { bookId: string };
  VideoDetail: { videoId: string };
  MusicDetail: { musicId: string };
  Cart: undefined;
  Checkout: undefined;
  BuyNowCheckout: undefined;
  CheckoutAddress: { flow?: 'cart' | 'buy_now'; buyNowLine?: BuyNowLineParam };
  OrderSummary: { address: Address; flow?: 'cart' | 'buy_now'; buyNowLine?: BuyNowLineParam };
  PaymentMethod: { address: Address; flow?: 'cart' | 'buy_now'; buyNowLine?: BuyNowLineParam };
  OrderConfirmation: { orderId?: string; order?: any };
  Search: { initialQuery?: string };
  Category: { categoryId: string; type: 'product' | 'book' | 'video' | 'music' };
  Auth: undefined;
  Profile: undefined;
  Wishlist: undefined;
  Orders: undefined;
  Downloads: undefined;
  Settings: undefined;
  PDFReader: { bookId: string };
  VideoPlayer: { videoId: string };
  MusicPlayer: { musicId: string };
};

export type BottomTabParamList = {
  Home: undefined;
  Shop: undefined;
  Books: undefined;
  More: undefined;
  Videos: undefined;
  Music: undefined;
  Profile: undefined;
};

// =============================================
// REDUX STATE TYPES
// =============================================

export interface RootState {
  auth: AuthState;
  cart: CartState;
  wishlist: WishlistState;
  user: UserState;
  app: AppState;
}

export interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

export interface CartState {
  cart: Cart;
  isLoading: boolean;
  error: string | null;
}

export interface WishlistState {
  items: WishlistItem[];
  isLoading: boolean;
  error: string | null;
}

export interface UserState {
  profile: User | null;
  addresses: Address[];
  orders: Order[];
  downloads: Download[];
  playlists: Playlist[];
  history: HistoryItem[];
  isLoading: boolean;
  error: string | null;
}

export interface AppState {
  isFirstLaunch: boolean;
  theme: 'light' | 'dark';
  language: string;
  notifications: Notification[];
  fcmToken: string | null;
}
