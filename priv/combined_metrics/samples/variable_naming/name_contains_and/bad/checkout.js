// Checkout and payment processing with compound variable names using 'and'.
// BAD: variables combine two concepts with 'and' instead of being split.

async function processOrder(order) {
  const userAndAddress = await fetchUserAndAddress(order.userId);
  const priceAndTax = calculatePriceAndTax(order.items);
  const shippingAndHandling = calculateShippingAndHandling(userAndAddress, order.items);

  const total = priceAndTax.subtotal + priceAndTax.tax + shippingAndHandling;

  return {
    user: userAndAddress.user,
    address: userAndAddress.address,
    total,
  };
}

function applyDiscounts(cart, coupons) {
  const priceAndDiscount = computePriceAndDiscount(cart, coupons);

  return {
    original: priceAndDiscount.price,
    savings: priceAndDiscount.discount,
    final: priceAndDiscount.price - priceAndDiscount.discount,
  };
}

async function buildReceipt(order) {
  const nameAndEmail = await getNameAndEmail(order.userId);
  const itemsAndQuantities = groupItemsAndQuantities(order.lineItems);
  const dateAndTime = new Date();

  return {
    customer: nameAndEmail.name,
    contact: nameAndEmail.email,
    lines: itemsAndQuantities,
    issuedAt: dateAndTime,
  };
}

async function validatePayment(payment) {
  const cardAndBilling = extractCardAndBilling(payment);

  if (!isValidCardAndBilling(cardAndBilling)) {
    throw new Error('Invalid card or billing details');
  }

  return cardAndBilling;
}

function splitOrder(order, vendorIds) {
  return vendorIds.map(vendorId => {
    const itemsAndTotals = filterItemsAndTotals(order, vendorId);
    return {
      vendorId,
      items: itemsAndTotals.items,
      subtotal: itemsAndTotals.total,
    };
  });
}

function summarizeCart(cart) {
  const countAndWeight = computeCountAndWeight(cart.items);
  const taxAndFees = computeTaxAndFees(cart.subtotal, cart.region);

  return {
    itemCount: countAndWeight.count,
    totalWeight: countAndWeight.weight,
    tax: taxAndFees.tax,
    fees: taxAndFees.fees,
    grandTotal: cart.subtotal + taxAndFees.tax + taxAndFees.fees,
  };
}

async function fetchUserAndAddress(userId) {
  return { user: { id: userId }, address: {} };
}

function calculatePriceAndTax(items) {
  const subtotal = items.length * 10;
  return { subtotal, tax: subtotal * 0.1 };
}

function calculateShippingAndHandling() { return 5; }
function computePriceAndDiscount(cart) { return { price: cart.total, discount: 0 }; }
async function getNameAndEmail() { return { name: 'Alice', email: 'alice@example.com' }; }
function groupItemsAndQuantities(items) { return items; }
function extractCardAndBilling(payment) { return payment; }
function isValidCardAndBilling() { return true; }
function filterItemsAndTotals(order) { return { items: order.lineItems, total: 0 }; }
function computeCountAndWeight(items) { return { count: items.length, weight: 0 }; }
function computeTaxAndFees(subtotal) { return { tax: subtotal * 0.1, fees: 2 }; }

module.exports = { processOrder, applyDiscounts, buildReceipt, validatePayment, splitOrder, summarizeCart };
