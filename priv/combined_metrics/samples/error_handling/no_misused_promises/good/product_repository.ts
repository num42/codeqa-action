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
  const available = await isProductAvailable(productId);

  if (available) {
    console.log(`Adding product ${productId} to cart`);
  } else {
    console.log(`Product ${productId} is out of stock`);
  }
}

async function loadAndFilterProducts(ids: string[]): Promise<Product[]> {
  const products = await Promise.all(ids.map((id) => fetchProduct(id)));
  return products.filter((p) => p.inStock);
}

function setupProductEventListeners(productId: string): void {
  const button = document.querySelector(`[data-product="${productId}"]`);
  if (!button) return;

  button.addEventListener("click", () => {
    handleAddToCart(productId).catch((err) => {
      console.error("Failed to add to cart", err);
    });
  });
}

async function validateBeforeCheckout(cartItems: string[]): Promise<string[]> {
  const checks = await Promise.all(
    cartItems.map(async (id) => {
      const available = await isProductAvailable(id);
      return available ? null : id;
    })
  );
  return checks.filter((id): id is string => id !== null);
}

export { fetchProduct, isProductAvailable, handleAddToCart, loadAndFilterProducts, validateBeforeCheckout, setupProductEventListeners };
export type { Product };
