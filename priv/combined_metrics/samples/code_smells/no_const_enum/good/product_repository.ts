enum ProductStatus {
  Draft = "draft",
  Active = "active",
  Archived = "archived",
  OutOfStock = "out_of_stock",
}

enum ProductCategory {
  Electronics = "electronics",
  Clothing = "clothing",
  Food = "food",
  Books = "books",
  Other = "other",
}

enum SortOrder {
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
  const labels: Record<ProductStatus, string> = {
    [ProductStatus.Draft]: "Draft",
    [ProductStatus.Active]: "Active",
    [ProductStatus.Archived]: "Archived",
    [ProductStatus.OutOfStock]: "Out of Stock",
  };
  return labels[status];
}

export { fetchProducts, isAvailable, getStatusLabel, ProductStatus, ProductCategory, SortOrder };
export type { Product, ProductQuery };
