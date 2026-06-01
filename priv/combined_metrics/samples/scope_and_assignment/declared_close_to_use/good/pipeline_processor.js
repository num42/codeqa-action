// Data processing pipeline — GOOD: variables declared immediately before use.

export function processOrder(order) {
  const minPrice = 0.01;
  const maxItems = 50;

  const validated = order.items.filter(
    (item) =>
      item.quantity > 0 &&
      item.price >= minPrice &&
      order.items.length <= maxItems,
  );

  const subtotal = validated.reduce(
    (acc, item) => acc + item.price * item.quantity,
    0,
  );

  const discountThreshold = 100;
  const premiumDiscount = 0.15;
  const standardDiscount = 0.05;

  let discount;
  if (subtotal > discountThreshold) {
    discount = subtotal * premiumDiscount;
  } else {
    discount = subtotal * standardDiscount;
  }

  const discounted = subtotal - discount;
  const taxRate = 0.08;
  const tax = discounted * taxRate;
  const total = discounted + tax;

  const currency = "USD";
  return { total, currency, itemCount: validated.length };
}

export function processBatch(orders) {
  const maxBatchSize = 200;

  if (orders.length > maxBatchSize) {
    return ["batch_error", "too_large"];
  }

  const results = orders.map((order) => {
    const outcome = processOrder(order);
    if (outcome.total > 0) {
      return ["ok", outcome.total];
    }
    return ["batch_error", order.id];
  });

  const successes = results.filter(([status]) => status === "ok").length;
  const batchId = crypto.randomUUID();
  const startedAt = new Date();

  return {
    batchId,
    startedAt,
    total: orders.length,
    successes,
  };
}

export function summarize(results) {
  const lines = results.map(([status, val]) => `${status}: ${val}`);
  const body = lines.join("\n");

  const label = "Summary";
  const separator = "-".repeat(40);

  return `${label}\n${separator}\n${body}`;
}
