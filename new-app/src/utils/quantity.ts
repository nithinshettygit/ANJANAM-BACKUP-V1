import { Product } from '@/types';

export interface QuantityValidationResult {
  isValid: boolean;
  message?: string;
  maxQuantity: number;
}

export interface StockInfo {
  available: number;
  inStock: boolean;
  isLowStock: boolean;
}

/**
 * Get stock information from product or variant
 */
export const getStockInfo = (product: Product, variantId?: string): StockInfo => {
  let availableStock = 0;
  
  if (variantId) {
    // Check specific variant stock
    const variant = product.variants.find(v => v.id === variantId);
    availableStock = variant?.stockQuantity || 0;
  } else {
    // Use default variant or product stock
    availableStock = product.variants[0]?.stockQuantity || product.stockQuantity || 0;
  }
  
  return {
    available: availableStock,
    inStock: availableStock > 0 && product.inStock,
    isLowStock: availableStock <= 5 && availableStock > 0,
  };
};

/**
 * Validate quantity change for a product
 */
export const validateQuantityChange = (
  currentQuantity: number,
  delta: number,
  product: Product,
  variantId?: string
): QuantityValidationResult => {
  const newQuantity = currentQuantity + delta;
  const stockInfo = getStockInfo(product, variantId);
  const maxOrderQuantity = 10; // Maximum items per order
  const maxQuantity = Math.min(maxOrderQuantity, stockInfo.available);
  
  // Check minimum quantity
  if (newQuantity < 1) {
    return {
      isValid: false,
      message: 'Minimum quantity is 1',
      maxQuantity,
    };
  }
  
  // Check if product is in stock
  if (!stockInfo.inStock) {
    return {
      isValid: false,
      message: 'This item is currently out of stock',
      maxQuantity,
    };
  }
  
  // Check maximum quantity limits
  if (newQuantity > maxQuantity) {
    if (stockInfo.available <= currentQuantity) {
      return {
        isValid: false,
        message: `Only ${stockInfo.available} items available in stock`,
        maxQuantity,
      };
    } else if (newQuantity > maxOrderQuantity) {
      return {
        isValid: false,
        message: `Maximum ${maxOrderQuantity} items allowed per order`,
        maxQuantity,
      };
    } else {
      return {
        isValid: false,
        message: `Only ${stockInfo.available} items left in stock`,
        maxQuantity,
      };
    }
  }
  
  return {
    isValid: true,
    maxQuantity,
  };
};

/**
 * Get stock status message for display
 */
export const getStockStatusMessage = (product: Product, variantId?: string): string | null => {
  const stockInfo = getStockInfo(product, variantId);
  
  if (!stockInfo.inStock) {
    return 'Out of Stock';
  }
  
  if (stockInfo.isLowStock) {
    return `Only ${stockInfo.available} left`;
  }
  
  return null;
};

/**
 * Calculate total price for quantity
 */
export const calculateTotalPrice = (
  price: number,
  quantity: number,
  currency: string = 'INR'
): { total: number; currency: string } => {
  return {
    total: price * quantity,
    currency,
  };
};

/**
 * Validate cart item quantities against current stock
 */
export const validateCartQuantities = (cartItems: any[], products: Product[]): {
  validItems: any[];
  invalidItems: { item: any; reason: string }[];
} => {
  const validItems: any[] = [];
  const invalidItems: { item: any; reason: string }[] = [];
  
  cartItems.forEach(cartItem => {
    const product = products.find(p => p.id === cartItem.product.id);
    if (!product) {
      invalidItems.push({
        item: cartItem,
        reason: 'Product no longer available',
      });
      return;
    }
    
    const validation = validateQuantityChange(
      0, // Start from 0 to check if current quantity is valid
      cartItem.quantity,
      product,
      cartItem.variant?.id
    );
    
    if (validation.isValid) {
      validItems.push(cartItem);
    } else {
      invalidItems.push({
        item: cartItem,
        reason: validation.message || 'Invalid quantity',
      });
    }
  });
  
  return { validItems, invalidItems };
};

/**
 * Get recommended quantity based on stock and limits
 */
export const getRecommendedQuantity = (
  product: Product,
  variantId?: string
): number => {
  const stockInfo = getStockInfo(product, variantId);
  
  if (!stockInfo.inStock) {
    return 0;
  }
  
  // Recommend 1 as default, or max available if less than 1
  return Math.min(1, stockInfo.available);
};

/**
 * Format stock status for UI display
 */
export const formatStockStatus = (
  product: Product,
  variantId?: string
): {
  text: string;
  color: string;
  icon: string;
} => {
  const stockInfo = getStockInfo(product, variantId);
  
  if (!stockInfo.inStock) {
    return {
      text: 'Out of Stock',
      color: '#F44336',
      icon: 'close-circle',
    };
  }
  
  if (stockInfo.isLowStock) {
    return {
      text: `Only ${stockInfo.available} left`,
      color: '#FF9800',
      icon: 'alert-circle',
    };
  }
  
  return {
    text: 'In Stock',
    color: '#4CAF50',
    icon: 'check-circle',
  };
};
