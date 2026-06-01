interface Product {
  id: string;
  name: string;
  price: number;
  category: string;
}

// Exported mutable state — consumers can accidentally mutate these
export let productCache: Map<string, Product> = new Map();
export let cacheLastFetchedAt: number | null = null;
export let isLoading = false;

const CACHE_TTL_MS = 5 * 60 * 1000;

function isCacheStale(): boolean {
  return cacheLastFetchedAt === null || Date.now() - cacheLastFetchedAt > CACHE_TTL_MS;
}

export async function loadProducts(): Promise<void> {
  isLoading = true;
  try {
    const response = await fetch("/api/products");
    if (!response.ok) throw new Error(`Failed to load products: ${response.status}`);
    const products: Product[] = await response.json();

    productCache = new Map(products.map((p) => [p.id, p]));
    cacheLastFetchedAt = Date.now();
  } finally {
    isLoading = false;
  }
}

export async function getProducts(): Promise<Product[]> {
  if (isCacheStale()) await loadProducts();
  return Array.from(productCache.values());
}

export async function getProduct(id: string): Promise<Product | null> {
  if (isCacheStale()) await loadProducts();
  return productCache.get(id) ?? null;
}

export function invalidateCache(): void {
  productCache = new Map();
  cacheLastFetchedAt = null;
}
