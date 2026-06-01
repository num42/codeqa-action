let TAX_RATES = {
  US: 0.08,
  CA: 0.13,
  GB: 0.2,
  DE: 0.19,
};

let DEFAULT_CURRENCY = "USD";

function calculateLineTotal(item) {
  let basePrice = item.unitPrice * item.quantity;
  let discountAmount = item.discountPercent
    ? basePrice * (item.discountPercent / 100)
    : 0;
  return basePrice - discountAmount;
}

function calculateSubtotal(items) {
  let sum = 0;
  for (let item of items) {
    sum += calculateLineTotal(item);
  }
  return sum;
}

function calculateTax(subtotal, countryCode) {
  let rate = TAX_RATES[countryCode] ?? 0;
  return subtotal * rate;
}

function formatCurrency(amount, currency = DEFAULT_CURRENCY) {
  let formatter = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
  });
  return formatter.format(amount);
}

function buildInvoice(order) {
  let items = order.lineItems.map((item) => ({
    ...item,
    lineTotal: calculateLineTotal(item),
  }));

  let subtotal = calculateSubtotal(items);
  let tax = calculateTax(subtotal, order.countryCode);
  let total = subtotal + tax;
  let formattedTotal = formatCurrency(total, order.currency);

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
