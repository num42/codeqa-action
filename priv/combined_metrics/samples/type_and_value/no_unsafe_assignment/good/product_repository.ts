interface Product {
  id: string;
  name: string;
  price: number;
  category: string;
  stock: number;
  tags: string[];
}

interface RawApiProduct {
  id: string;
  name: string;
  price_cents: number;
  category_slug: string;
  inventory_count: number;
  tag_list: string;
}

function parseProduct(raw: RawApiProduct): Product {
  return {
    id: raw.id,
    name: raw.name,
    price: raw.price_cents / 100,
    category: raw.category_slug,
    stock: raw.inventory_count,
    tags: raw.tag_list ? raw.tag_list.split(",").map((t) => t.trim()) : [],
  };
}

async function fetchProducts(categorySlug: string): Promise<Product[]> {
  const response = await fetch(`/api/products?category=${categorySlug}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch products: ${response.status}`);
  }

  const rawProducts: RawApiProduct[] = await response.json();
  return rawProducts.map(parseProduct);
}

async function fetchProduct(productId: string): Promise<Product> {
  const response = await fetch(`/api/products/${productId}`);

  if (!response.ok) {
    throw new Error(`Product not found: ${productId}`);
  }

  const raw: RawApiProduct = await response.json();
  return parseProduct(raw);
}

function filterInStock(products: Product[]): Product[] {
  return products.filter((p) => p.stock > 0);
}

function sortByPrice(products: Product[], direction: "asc" | "desc" = "asc"): Product[] {
  return [...products].sort((a, b) =>
    direction === "asc" ? a.price - b.price : b.price - a.price
  );
}

export { fetchProducts, fetchProduct, filterInStock, sortByPrice };
export type { Product };
