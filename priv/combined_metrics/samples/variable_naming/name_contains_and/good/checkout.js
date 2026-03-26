// Checkout and payment processing with separate, focused variable names.
// GOOD: each variable holds one concept; compound data uses plain objects.

async function processOrder(order) {
  const user = await fetchUser(order.userId);
  const address = await fetchAddress(order.userId);
  const subtotal = calculateSubtotal(order.items);
  const tax = calculateTax(subtotal);
  const shipping = calculateShipping(address, order.items);

  const total = subtotal + tax + shipping;

  return { user, address, total };
}

function applyDiscounts(cart, coupons) {
  const price = cart.total;
  const discount = computeDiscount(cart, coupons);

  return {
    original: price,
    savings: discount,
    final: price - discount,
  };
}

async function buildReceipt(order) {
  const name = await fetchCustomerName(order.userId);
  const email = await fetchCustomerEmail(order.userId);
  const lineItems = groupLineItems(order.lineItems);
  const issuedAt = new Date();

  return { customer: name, contact: email, lines: lineItems, issuedAt };
}

async function validatePayment(payment) {
  const card = extractCard(payment);
  const billing = extractBilling(payment);

  if (!isValidCard(card) || !isValidBilling(billing)) {
    throw new Error('Invalid card or billing details');
  }

  return { card, billing };
}

function splitOrder(order, vendorIds) {
  return vendorIds.map(vendorId => {
    const items = filterItemsByVendor(order, vendorId);
    const subtotal = sumItems(items);
    return { vendorId, items, subtotal };
  });
}

function summarizeCart(cart) {
  const count = cart.items.length;
  const weight = computeWeight(cart.items);
  const tax = computeTax(cart.subtotal, cart.region);
  const fees = computeFees(cart.subtotal, cart.region);

  return {
    itemCount: count,
    totalWeight: weight,
    tax,
    fees,
    grandTotal: cart.subtotal + tax + fees,
  };
}

async function fetchUser(userId) { return { id: userId }; }
async function fetchAddress() { return {}; }
function calculateSubtotal(items) { return items.length * 10; }
function calculateTax(subtotal) { return subtotal * 0.1; }
function calculateShipping() { return 5; }
function computeDiscount() { return 0; }
async function fetchCustomerName() { return 'Alice'; }
async function fetchCustomerEmail() { return 'alice@example.com'; }
function groupLineItems(items) { return items; }
function extractCard(payment) { return payment.card; }
function extractBilling(payment) { return payment.billing; }
function isValidCard() { return true; }
function isValidBilling() { return true; }
function filterItemsByVendor(order) { return order.lineItems; }
function sumItems(items) { return items.length * 10; }
function computeWeight() { return 0; }
function computeTax(subtotal) { return subtotal * 0.1; }
function computeFees() { return 2; }

module.exports = { processOrder, applyDiscounts, buildReceipt, validatePayment, splitOrder, summarizeCart };
