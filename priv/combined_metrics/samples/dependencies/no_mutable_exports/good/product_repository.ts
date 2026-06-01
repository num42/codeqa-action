interface Product {
  id: string;
  name: string;
  price: number;
  category: string;
}

interface CacheState {
  products: Map<string, Product>;
  lastFetchedAt: number | null;
}

const state: CacheState = {
  products: new Map(),
  lastFetchedAt: null,
};

const CACHE_TTL_MS = 5 * 60 * 1000;

function isCacheStale(): boolean {
  return state.lastFetchedAt === null || Date.now() - state.lastFetchedAt > CACHE_TTL_MS;
}

async function loadProducts(): Promise<void> {
  const response = await fetch("/api/products");
  if (!response.ok) throw new Error(`Failed to load products: ${response.status}`);
  const products: Product[] = await response.json();

  state.products.clear();
  for (const product of products) {
    state.products.set(product.id, product);
  }
  state.lastFetchedAt = Date.now();
}

async function getProducts(): Promise<Product[]> {
  if (isCacheStale()) await loadProducts();
  return Array.from(state.products.values());
}

async function getProduct(id: string): Promise<Product | null> {
  if (isCacheStale()) await loadProducts();
  return state.products.get(id) ?? null;
}

function invalidateCache(): void {
  state.products.clear();
  state.lastFetchedAt = null;
}

function getCacheAge(): number | null {
  if (state.lastFetchedAt === null) return null;
  return Date.now() - state.lastFetchedAt;
}

export { getProducts, getProduct, invalidateCache, getCacheAge, loadProducts };
export type { Product };
