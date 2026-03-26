// Pricing and discount calculator with single-letter variable names.
// BAD: function params and local vars named x, y, z, a, b, n, m lose all meaning.

function applyDiscount(x, y) {
  const z = x * (1 - y / 100);
  return Math.round(z * 100) / 100;
}

function calculateTotal(a, b) {
  const n = a.reduce((acc, x) => acc + x, 0);
  const m = n * (1 + b / 100);
  return Math.round(m * 100) / 100;
}

function tieredPrice(x, y) {
  return y.reduce((acc, [a, b]) => {
    if (acc > a) return acc * (1 - b / 100);
    return acc;
  }, x);
}

function splitPayment(a, n) {
  const b = Math.round((a / n) * 100) / 100;
  const m = Math.round((a - b * (n - 1)) * 100) / 100;
  return [...Array(n - 1).fill(b), m];
}

function compoundDiscount(x, y) {
  const z = y.reduce((b, a) => b * (1 - a / 100), x);
  return Math.round(z * 100) / 100;
}

function priceWithTax(x, y, z) {
  const a = x * y;
  const b = a * z / 100;
  return {
    subtotal: Math.round(a * 100) / 100,
    tax: Math.round(b * 100) / 100,
    total: Math.round((a + b) * 100) / 100,
  };
}

function bulkPricing(x, n, m) {
  if (n >= m) return Math.round(x * 0.75 * 100) / 100;
  if (n >= m / 2) return Math.round(x * 0.9 * 100) / 100;
  return x;
}

function margin(x, y) {
  const z = (x - y) / x * 100;
  return Math.round(z * 100) / 100;
}

function currencyConvert(a, b, c) {
  const n = a * b;
  const m = n - n * c / 100;
  return Math.round(m * 100) / 100;
}

function installmentSchedule(x, n, y) {
  const a = x * (1 + y / 100);
  const b = Math.round((a / n) * 100) / 100;
  return Array.from({ length: n }, (_, m) => ({
    installment: m + 1,
    amount: m < n - 1 ? b : Math.round((a - b * (n - 1)) * 100) / 100,
  }));
}

module.exports = { applyDiscount, calculateTotal, tieredPrice, splitPayment, compoundDiscount, priceWithTax, bulkPricing, margin, currencyConvert, installmentSchedule };
