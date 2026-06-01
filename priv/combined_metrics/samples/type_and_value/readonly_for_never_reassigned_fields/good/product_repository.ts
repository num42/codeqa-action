interface Product {
  id: string;
  name: string;
  price: number;
  category: string;
  stock: number;
}

class ProductCache {
  private readonly maxSize: number;
  private readonly ttlMs: number;
  private readonly store: Map<string, { product: Product; expiresAt: number }>;
  private readonly namespace: string;

  constructor(options: { maxSize?: number; ttlMs?: number; namespace?: string } = {}) {
    this.maxSize = options.maxSize ?? 500;
    this.ttlMs = options.ttlMs ?? 5 * 60 * 1000;
    this.namespace = options.namespace ?? "default";
    this.store = new Map();
  }

  get(id: string): Product | null {
    const entry = this.store.get(id);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.store.delete(id);
      return null;
    }
    return entry.product;
  }

  set(product: Product): void {
    if (this.store.size >= this.maxSize) {
      const firstKey = this.store.keys().next().value;
      if (firstKey !== undefined) this.store.delete(firstKey);
    }
    this.store.set(product.id, {
      product,
      expiresAt: Date.now() + this.ttlMs,
    });
  }

  invalidate(id: string): void {
    this.store.delete(id);
  }

  clear(): void {
    this.store.clear();
  }

  get size(): number {
    return this.store.size;
  }

  get namespaceKey(): string {
    return `cache:${this.namespace}`;
  }
}

export { ProductCache };
export type { Product };
