interface Product {
  id: string;
  name: string;
  price: number;
  category: string;
  stock: number;
  tags: string[];
}

async function fetchProducts(categorySlug: string): Promise<Product[]> {
  const response = await fetch(`/api/products?category=${categorySlug}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch products: ${response.status}`);
  }

  // Unsafe: any assigned directly to typed variable
  const rawProducts: any = await response.json();
  const products: Product[] = rawProducts;
  return products;
}

async function fetchProduct(productId: string): Promise<Product> {
  const response = await fetch(`/api/products/${productId}`);

  if (!response.ok) {
    throw new Error(`Product not found: ${productId}`);
  }

  const data: any = await response.json();
  const product: Product = data.product;
  return product;
}

function enrichProduct(product: Product, extraData: any): Product {
  const enriched: Product = { ...product, ...extraData };
  return enriched;
}

function parseProductList(payload: any): Product[] {
  const items: Product[] = payload.items;
  return items;
}

function filterInStock(products: Product[]): Product[] {
  return products.filter((p) => p.stock > 0);
}

function sortByPrice(products: Product[], direction: "asc" | "desc" = "asc"): Product[] {
  return [...products].sort((a, b) =>
    direction === "asc" ? a.price - b.price : b.price - a.price
  );
}

export { fetchProducts, fetchProduct, enrichProduct, parseProductList, filterInStock, sortByPrice };
export type { Product };
