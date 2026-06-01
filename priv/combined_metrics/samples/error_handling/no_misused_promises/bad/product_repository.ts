interface Product {
  id: string;
  name: string;
  inStock: boolean;
}

async function fetchProduct(id: string): Promise<Product> {
  const response = await fetch(`/api/products/${id}`);
  if (!response.ok) throw new Error(`Product not found: ${id}`);
  return response.json() as Promise<Product>;
}

async function isProductAvailable(id: string): Promise<boolean> {
  const product = await fetchProduct(id);
  return product.inStock;
}

async function handleAddToCart(productId: string): Promise<void> {
  // Misuse: Promise<boolean> used directly in `if` without await
  if (isProductAvailable(productId)) {
    console.log(`Adding product ${productId} to cart`);
  } else {
    console.log(`Product ${productId} is out of stock`);
  }
}

function loadAndFilterProducts(ids: string[]): Product[] {
  const products: Product[] = [];

  ids.forEach(async (id) => {
    // Misuse: async callback in forEach — errors and results are ignored
    const product = await fetchProduct(id);
    if (product.inStock) {
      products.push(product);
    }
  });

  return products;
}

function setupProductEventListeners(productId: string): void {
  const button = document.querySelector(`[data-product="${productId}"]`);
  if (!button) return;

  // Misuse: async function passed where void callback is expected with no error handling
  button.addEventListener("click", async () => {
    await handleAddToCart(productId);
  });
}

async function validateBeforeCheckout(cartItems: string[]): Promise<string[]> {
  const unavailable: string[] = [];

  cartItems.forEach(async (id) => {
    // Misuse: async in forEach, result never collected
    const available = await isProductAvailable(id);
    if (!available) unavailable.push(id);
  });

  return unavailable;
}

export { fetchProduct, isProductAvailable, handleAddToCart, loadAndFilterProducts, validateBeforeCheckout };
export type { Product };
