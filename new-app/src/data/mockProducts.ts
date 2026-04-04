import { Product, Category } from '@/types';

// Mock Categories
export const mockCategories: Category[] = [
  {
    id: 'cat-1',
    name: 'Meditation',
    slug: 'meditation',
    description: 'Products for meditation and mindfulness',
    image: 'https://via.placeholder.com/400x200?text=Meditation',
  },
  {
    id: 'cat-2',
    name: 'Yoga',
    slug: 'yoga',
    description: 'Yoga mats, blocks, and accessories',
    image: 'https://via.placeholder.com/400x200?text=Yoga',
  },
  {
    id: 'cat-3',
    name: 'Spiritual Items',
    slug: 'spiritual-items',
    description: 'Spiritual and religious items',
    image: 'https://via.placeholder.com/400x200?text=Spiritual',
  },
  {
    id: 'cat-4',
    name: 'Wellness',
    slug: 'wellness',
    description: 'Health and wellness products',
    image: 'https://via.placeholder.com/400x200?text=Wellness',
  },
  {
    id: 'cat-5',
    name: 'Incense',
    slug: 'incense',
    description: 'Incense sticks and aromatherapy',
    image: 'https://via.placeholder.com/400x200?text=Incense',
  },
];

// Mock Products
export const mockProducts: Product[] = [
  {
    id: 'prod-1',
    name: 'Premium Meditation Cushion',
    description: 'Comfortable meditation cushion filled with organic buckwheat hulls. Perfect for long meditation sessions.',
    price: 1299,
    currency: 'INR',
    stockQuantity: 25,
    inStock: true,
    images: [
      { id: 'img-1', url: 'https://via.placeholder.com/400x400?text=Meditation+Cushion', alt: 'Meditation Cushion' },
    ],
    category: mockCategories[0],
    variants: [],
    rating: 4.5,
    reviewCount: 128,
    attributes: [
      { id: 'attr-1', name: 'Color', value: 'Purple' },
      { id: 'attr-2', name: 'Material', value: 'Cotton' },
      { id: 'attr-3', name: 'Size', value: '16 inch diameter' },
    ],
    slug: 'premium-meditation-cushion',
    createdAt: '2024-01-15T10:00:00Z',
  },
  {
    id: 'prod-2',
    name: 'Yoga Mat - Non-Slip',
    description: 'Eco-friendly yoga mat with excellent grip and cushioning. 6mm thickness for joint protection.',
    price: 999,
    currency: 'INR',
    images: [
      { id: 'img-2', url: 'https://via.placeholder.com/400x400?text=Yoga+Mat', alt: 'Yoga Mat' },
    ],
    category: mockCategories[1],
    variants: [
      { id: 'var-1', name: 'Blue', price: 999, stockQuantity: 30, inStock: true, attributes: { color: 'Blue' } },
      { id: 'var-2', name: 'Green', price: 999, stockQuantity: 20, inStock: true, attributes: { color: 'Green' } },
    ],
    inStock: true,
    stockQuantity: 50,
    rating: 4.8,
    reviewCount: 342,
    attributes: [
      { id: 'attr-4', name: 'Thickness', value: '6mm' },
      { id: 'attr-5', name: 'Material', value: 'TPE' },
      { id: 'attr-6', name: 'Size', value: '183 x 61 cm' },
    ],
    slug: 'yoga-mat-non-slip',
    createdAt: '2024-01-16T10:00:00Z',
  },
  {
    id: 'prod-3',
    name: 'Tibetan Singing Bowl',
    description: 'Hand-hammered Tibetan singing bowl for meditation and sound healing. Includes wooden striker and cushion.',
    price: 2499,
    currency: 'INR',
    images: [
      { id: 'img-3', url: 'https://via.placeholder.com/400x400?text=Singing+Bowl', alt: 'Singing Bowl' },
    ],
    category: mockCategories[2],
    variants: [],
    inStock: true,
    stockQuantity: 15,
    rating: 4.9,
    reviewCount: 89,
    attributes: [
      { id: 'attr-7', name: 'Diameter', value: '10 cm' },
      { id: 'attr-8', name: 'Material', value: 'Bronze' },
      { id: 'attr-9', name: 'Origin', value: 'Nepal' },
    ],
    slug: 'tibetan-singing-bowl',
    createdAt: '2024-01-17T10:00:00Z',
  },
  {
    id: 'prod-4',
    name: 'Aromatherapy Diffuser',
    description: 'Ultrasonic essential oil diffuser with 7-color LED lights. Creates calming mist for relaxation.',
    price: 1499,
    currency: 'INR',
    images: [
      { id: 'img-4', url: 'https://via.placeholder.com/400x400?text=Diffuser', alt: 'Diffuser' },
    ],
    category: mockCategories[3],
    variants: [],
    inStock: true,
    stockQuantity: 35,
    rating: 4.6,
    reviewCount: 215,
    attributes: [
      { id: 'attr-10', name: 'Capacity', value: '300ml' },
      { id: 'attr-11', name: 'Material', value: 'BPA-Free Plastic' },
      { id: 'attr-12', name: 'Timer', value: '1/3/6 hours' },
    ],
    slug: 'aromatherapy-diffuser',
    createdAt: '2024-01-18T10:00:00Z',
  },
  {
    id: 'prod-5',
    name: 'Sandalwood Incense Sticks',
    description: 'Natural sandalwood incense sticks. 100% organic, no chemicals. Pack of 100 sticks.',
    price: 299,
    currency: 'INR',
    images: [
      { id: 'img-5', url: 'https://via.placeholder.com/400x400?text=Incense', alt: 'Incense' },
    ],
    category: mockCategories[4],
    variants: [],
    inStock: true,
    stockQuantity: 100,
    rating: 4.7,
    reviewCount: 456,
    attributes: [
      { id: 'attr-13', name: 'Quantity', value: '100 sticks' },
      { id: 'attr-14', name: 'Burn Time', value: '45 minutes each' },
      { id: 'attr-15', name: 'Scent', value: 'Sandalwood' },
    ],
    slug: 'sandalwood-incense-sticks',
    createdAt: '2024-01-19T10:00:00Z',
  },
  {
    id: 'prod-6',
    name: 'Meditation Timer Bell',
    description: 'Beautiful brass meditation timer with soothing bell sound. Battery operated with adjustable intervals.',
    price: 899,
    currency: 'INR',
    images: [
      { id: 'img-6', url: 'https://via.placeholder.com/400x400?text=Timer+Bell', alt: 'Timer Bell' },
    ],
    category: mockCategories[0],
    variants: [],
    inStock: false,
    stockQuantity: 0,
    rating: 4.4,
    reviewCount: 67,
    attributes: [
      { id: 'attr-16', name: 'Material', value: 'Brass' },
      { id: 'attr-17', name: 'Battery', value: '2 x AAA' },
      { id: 'attr-18', name: 'Intervals', value: '5/10/15/30 min' },
    ],
    slug: 'meditation-timer-bell',
    createdAt: '2024-01-20T10:00:00Z',
  },
  {
    id: 'prod-7',
    name: 'Crystal Healing Set',
    description: 'Set of 7 chakra healing crystals with velvet pouch. Perfect for energy balancing and meditation.',
    price: 1799,
    currency: 'INR',
    images: [
      { id: 'img-7', url: 'https://via.placeholder.com/400x400?text=Crystals', alt: 'Crystals' },
    ],
    category: mockCategories[2],
    variants: [],
    inStock: true,
    stockQuantity: 20,
    rating: 4.8,
    reviewCount: 134,
    attributes: [
      { id: 'attr-19', name: 'Crystals', value: '7 pieces' },
      { id: 'attr-20', name: 'Size', value: '2-3 cm each' },
      { id: 'attr-21', name: 'Pouch', value: 'Velvet included' },
    ],
    slug: 'crystal-healing-set',
    createdAt: '2024-01-21T10:00:00Z',
  },
  {
    id: 'prod-8',
    name: 'Yoga Block Set (2 pcs)',
    description: 'High-density foam yoga blocks for support and alignment. Lightweight and durable.',
    price: 599,
    currency: 'INR',
    images: [
      { id: 'img-8', url: 'https://via.placeholder.com/400x400?text=Yoga+Blocks', alt: 'Yoga Blocks' },
    ],
    category: mockCategories[1],
    variants: [],
    inStock: true,
    stockQuantity: 45,
    rating: 4.5,
    reviewCount: 187,
    attributes: [
      { id: 'attr-22', name: 'Quantity', value: '2 blocks' },
      { id: 'attr-23', name: 'Material', value: 'EVA Foam' },
      { id: 'attr-24', name: 'Size', value: '23 x 15 x 10 cm' },
    ],
    slug: 'yoga-block-set',
    createdAt: '2024-01-22T10:00:00Z',
  },
];

// Helper functions
export const getProductById = (id: string): Product | undefined => {
  return mockProducts.find((p) => p.id === id);
};

export const getProductsByCategory = (categoryId: string): Product[] => {
  return mockProducts.filter((p) => p.category.id === categoryId);
};

export const searchProducts = (query: string): Product[] => {
  const lowerQuery = query.toLowerCase();
  return mockProducts.filter(
    (p) =>
      p.name.toLowerCase().includes(lowerQuery) ||
      p.description.toLowerCase().includes(lowerQuery) ||
      p.category.name.toLowerCase().includes(lowerQuery)
  );
};
