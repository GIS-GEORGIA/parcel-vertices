/** Prices are in tetri (1 GEL = 100 tetri). Change here only; no DB migration needed. */
export interface Product {
  id: string;
  credits: number;
  amountTetri: number;
}

export const PRODUCTS: Product[] = [
  { id: 'single', credits: 1, amountTetri: 300 },
  { id: 'pack10', credits: 10, amountTetri: 2500 },
  { id: 'pack50', credits: 50, amountTetri: 10000 },
  { id: 'pack200', credits: 200, amountTetri: 30000 },
];

/** Free demo parcels: unlockable by any registered user without credits. */
export const DEMO_CODES = ['01.13.08.001.009', '03.03.26.242', '05.21.22.002'];
