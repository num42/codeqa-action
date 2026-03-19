const TAX_RATES = {
  US: 0.08,
  CA: 0.13,
  GB: 0.2,
  DE: 0.19,
};

const DEFAULT_CURRENCY = "USD";

function calculateLineTotal(item) {
  const basePrice = item.unitPrice * item.quantity;
  const discountAmount = item.discountPercent
    ? basePrice * (item.discountPercent / 100)
    : 0;
  return basePrice - discountAmount;
}

function calculateSubtotal(items) {
  return items.reduce((sum, item) => sum + calculateLineTotal(item), 0);
}

function calculateTax(subtotal, countryCode) {
  const rate = TAX_RATES[countryCode] ?? 0;
  return subtotal * rate;
}

function formatCurrency(amount, currency = DEFAULT_CURRENCY) {
  const formatter = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
  });
  return formatter.format(amount);
}

function buildInvoice(order) {
  const items = order.lineItems.map((item) => ({
    ...item,
    lineTotal: calculateLineTotal(item),
  }));

  const subtotal = calculateSubtotal(items);
  const tax = calculateTax(subtotal, order.countryCode);
  const total = subtotal + tax;
  const formattedTotal = formatCurrency(total, order.currency);

  return {
    orderId: order.id,
    items,
    subtotal,
    tax,
    total,
    formattedTotal,
    currency: order.currency ?? DEFAULT_CURRENCY,
    issuedAt: new Date().toISOString(),
  };
}

export { buildInvoice, calculateSubtotal, calculateTax, formatCurrency };
