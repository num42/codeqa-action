// Data processing pipeline — BAD: variables declared far from their use.

export function processOrder(order) {
  // All variables declared upfront, used much later
  const taxRate = 0.08;
  const discountThreshold = 100;
  const premiumDiscount = 0.15;
  const standardDiscount = 0.05;
  const currency = "USD";
  const maxItems = 50;
  const minPrice = 0.01;

  const items = order.items;

  const validated = items.filter(
    (item) =>
      item.quantity > 0 &&
      item.price >= minPrice &&
      items.length <= maxItems,
  );

  const subtotal = validated.reduce(
    (acc, item) => acc + item.price * item.quantity,
    0,
  );

  // discountThreshold, premiumDiscount, standardDiscount declared ~17 lines ago
  let discount;
  if (subtotal > discountThreshold) {
    discount = subtotal * premiumDiscount;
  } else {
    discount = subtotal * standardDiscount;
  }

  const discounted = subtotal - discount;

  // taxRate declared ~26 lines ago
  const tax = discounted * taxRate;

  const total = discounted + tax;

  // currency declared ~29 lines ago
  return { total, currency, itemCount: validated.length };
}

export function processBatch(orders) {
  // Variables declared at top, used at different depths
  const batchId = crypto.randomUUID();
  const startedAt = new Date();
  const maxBatchSize = 200;
  const errorTag = "batch_error";

  if (orders.length > maxBatchSize) {
    // errorTag used for the first time ~6 lines after declaration
    return [errorTag, "too_large"];
  }

  const results = orders.map((order) => {
    const outcome = processOrder(order);
    if (outcome.total > 0) {
      return ["ok", outcome.total];
    }
    // errorTag used again here, many lines from declaration
    return [errorTag, order.id];
  });

  // startedAt and batchId used ~22 lines after declaration
  const successes = results.filter(([status]) => status === "ok").length;

  return {
    batchId,
    startedAt,
    total: orders.length,
    successes,
  };
}

export function summarize(results) {
  const label = "Summary";
  const separator = "-".repeat(40);
  const format = "detailed";

  const lines = results.map(([status, val]) => `${status}: ${val}`);
  const body = lines.join("\n");

  // label, separator, format all declared ~7 lines ago
  if (format === "detailed") {
    return `${label}\n${separator}\n${body}`;
  }
  return `${label}: ${lines.length} results`;
}
