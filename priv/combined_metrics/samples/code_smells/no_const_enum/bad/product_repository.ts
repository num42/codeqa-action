// const enum is inlined at compile time, breaking at runtime when used
// from JavaScript or with isolatedModules / bundlers
const enum ProductStatus {
  Draft = "draft",
  Active = "active",
  Archived = "archived",
  OutOfStock = "out_of_stock",
}

const enum ProductCategory {
  Electronics = "electronics",
  Clothing = "clothing",
  Food = "food",
  Books = "books",
  Other = "other",
}

const enum SortOrder {
  PriceAsc = "price_asc",
  PriceDesc = "price_desc",
  NameAsc = "name_asc",
  Newest = "newest",
}

interface Product {
  id: string;
  name: string;
  price: number;
  status: ProductStatus;
  category: ProductCategory;
  stock: number;
  createdAt: string;
}

interface ProductQuery {
  category?: ProductCategory;
  status?: ProductStatus;
  sortOrder?: SortOrder;
  page?: number;
  pageSize?: number;
}

async function fetchProducts(query: ProductQuery = {}): Promise<Product[]> {
  const params = new URLSearchParams();
  if (query.category) params.set("category", query.category);
  if (query.status) params.set("status", query.status);
  if (query.sortOrder) params.set("sort", query.sortOrder);
  if (query.page) params.set("page", String(query.page));
  if (query.pageSize) params.set("pageSize", String(query.pageSize));

  const response = await fetch(`/api/products?${params}`);
  if (!response.ok) throw new Error(`Failed to fetch products: ${response.status}`);
  return response.json() as Promise<Product[]>;
}

function isAvailable(product: Product): boolean {
  return product.status === ProductStatus.Active && product.stock > 0;
}

function getStatusLabel(status: ProductStatus): string {
  switch (status) {
    case ProductStatus.Draft: return "Draft";
    case ProductStatus.Active: return "Active";
    case ProductStatus.Archived: return "Archived";
    case ProductStatus.OutOfStock: return "Out of Stock";
  }
}

export { fetchProducts, isAvailable, getStatusLabel, ProductStatus, ProductCategory, SortOrder };
export type { Product, ProductQuery };
