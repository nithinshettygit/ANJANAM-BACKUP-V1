import type { Cart, Product, ProductVariant } from '@/types';

const GST_RATE = 0.18;
const FREE_SHIPPING_MIN_SUBTOTAL = 500;
const STANDARD_SHIPPING = 50;

export type BuyNowLineInput = {
  product: Product;
  variant?: ProductVariant;
  quantity: number;
};

/**
 * Build the same cart summary shape used by full-cart checkout (18% GST, free shipping over ₹500).
 * Used when buy-now line is passed via navigation so checkout never falls back to full cart by mistake.
 */
export function buildBuyNowCartSummary(line: BuyNowLineInput): Cart {
  const unit = line.variant?.price ?? line.product.price;
  const subtotal = Math.round(unit * line.quantity * 100) / 100;
  const tax = Math.round(subtotal * GST_RATE * 100) / 100;
  const shipping = subtotal >= FREE_SHIPPING_MIN_SUBTOTAL ? 0 : STANDARD_SHIPPING;
  const discount = 0;
  const total = Math.round((subtotal + tax + shipping - discount) * 100) / 100;
  const id = `${line.product.id}::${line.variant?.id ?? 'default'}`;

  return {
    items: [
      {
        id,
        product: line.product,
        quantity: line.quantity,
        variant: line.variant,
        addedAt: new Date().toISOString(),
      },
    ],
    subtotal,
    tax,
    shipping,
    discount,
    total,
    currency: line.product.currency || 'INR',
  };
}
