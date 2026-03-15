// Pricing and discount calculator with descriptive variable names.
// GOOD: params and locals named price, discount, quantity, amount make intent clear.

function applyDiscount(price, discountPercent) {
  const discounted = price * (1 - discountPercent / 100);
  return Math.round(discounted * 100) / 100;
}

function calculateTotal(amounts, taxRate) {
  const subtotal = amounts.reduce((acc, amount) => acc + amount, 0);
  const total = subtotal * (1 + taxRate / 100);
  return Math.round(total * 100) / 100;
}

function tieredPrice(price, tiers) {
  return tiers.reduce((currentPrice, [threshold, discountPercent]) => {
    if (currentPrice > threshold) return currentPrice * (1 - discountPercent / 100);
    return currentPrice;
  }, price);
}

function splitPayment(amount, count) {
  const installment = Math.round((amount / count) * 100) / 100;
  const lastInstallment = Math.round((amount - installment * (count - 1)) * 100) / 100;
  return [...Array(count - 1).fill(installment), lastInstallment];
}

function compoundDiscount(price, discountPercents) {
  const finalPrice = discountPercents.reduce(
    (currentPrice, discountPercent) => currentPrice * (1 - discountPercent / 100),
    price
  );
  return Math.round(finalPrice * 100) / 100;
}

function priceWithTax(unitPrice, quantity, taxRate) {
  const subtotal = unitPrice * quantity;
  const tax = subtotal * taxRate / 100;
  return {
    subtotal: Math.round(subtotal * 100) / 100,
    tax: Math.round(tax * 100) / 100,
    total: Math.round((subtotal + tax) * 100) / 100,
  };
}

function bulkPricing(price, quantity, bulkThreshold) {
  if (quantity >= bulkThreshold) return Math.round(price * 0.75 * 100) / 100;
  if (quantity >= bulkThreshold / 2) return Math.round(price * 0.9 * 100) / 100;
  return price;
}

function margin(sellingPrice, cost) {
  const marginPercent = (sellingPrice - cost) / sellingPrice * 100;
  return Math.round(marginPercent * 100) / 100;
}

function currencyConvert(amount, exchangeRate, conversionFee) {
  const converted = amount * exchangeRate;
  const afterFee = converted - converted * conversionFee / 100;
  return Math.round(afterFee * 100) / 100;
}

function installmentSchedule(principal, count, annualRate) {
  const totalAmount = principal * (1 + annualRate / 100);
  const installment = Math.round((totalAmount / count) * 100) / 100;
  return Array.from({ length: count }, (_, index) => ({
    installment: index + 1,
    amount: index < count - 1 ? installment : Math.round((totalAmount - installment * (count - 1)) * 100) / 100,
  }));
}

module.exports = { applyDiscount, calculateTotal, tieredPrice, splitPayment, compoundDiscount, priceWithTax, bulkPricing, margin, currencyConvert, installmentSchedule };
