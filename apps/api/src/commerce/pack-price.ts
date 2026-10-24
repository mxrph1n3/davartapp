import { Prisma } from '@prisma/client';

type Priced = {
  price: Prisma.Decimal | number;
  sellByPack?: boolean | null;
  packSize?: Prisma.Decimal | number | null;
};

/**
 * Price of one cart unit. Goods sold in packs (tile, flooring) are priced per м²
 * but the cart counts packs, so one unit costs price × м² in a pack.
 */
export function unitLinePrice(product: Priced): number {
  const price = Number(product.price);
  if (product.sellByPack && product.packSize != null) {
    return Math.round(price * Number(product.packSize) * 100) / 100;
  }
  return price;
}
