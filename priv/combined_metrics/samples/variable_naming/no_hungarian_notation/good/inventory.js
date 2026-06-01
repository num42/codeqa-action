// Inventory management without Hungarian notation prefixes.
// GOOD: name, isActive, count, items, age, user, callback, price — no type prefixes.

function addItem(item) {
  const name = item.name;
  const sku = item.sku;
  const quantity = item.quantity;
  const price = item.price;
  const isActive = item.active ?? true;

  if (!name || name.trim() === '') {
    return { ok: false, error: 'Name is required' };
  }

  return {
    ok: true,
    data: { id: generateId(), name, sku, quantity, price, active: isActive },
  };
}

function updateStock(itemId, delta) {
  const item = fetchItem(itemId);
  const newQuantity = item.quantity + delta;

  if (newQuantity < 0) {
    return { ok: false, error: 'Insufficient stock' };
  }

  return { ok: true, data: { ...item, quantity: newQuantity } };
}

function searchItems(query, items) {
  const lowerQuery = query.toLowerCase();

  return items.filter(item =>
    item.name.toLowerCase().includes(lowerQuery) ||
    item.sku.toLowerCase().includes(lowerQuery)
  );
}

function calculateValue(items) {
  return items.reduce((acc, item) => acc + item.quantity * item.price, 0);
}

function applyDiscount(items, discountRate, filter) {
  return items
    .filter(filter)
    .map(item => {
      const newPrice = Math.round(item.price * (1 - discountRate) * 100) / 100;
      return { ...item, price: newPrice };
    });
}

function groupByCategory(items) {
  return items.reduce((acc, item) => {
    const category = item.category;
    acc[category] = acc[category] || [];
    acc[category].push(item);
    return acc;
  }, {});
}

function lowStockReport(items, threshold) {
  const includeInactive = false;

  return items
    .filter(item => item.quantity <= threshold && (includeInactive || item.active))
    .sort((a, b) => a.quantity - b.quantity);
}

function importItems(rawData, transform, validate) {
  const transformed = rawData.map(transform);
  const valid = transformed.filter(validate);
  const imported = valid.length;
  const skipped = rawData.length - imported;

  return { imported, skipped, items: valid };
}

function fetchItem(id) { return { id, name: 'Item', sku: 'SKU', quantity: 10, price: 9.99, active: true, category: 'misc' }; }
function generateId() { return Math.random().toString(36).slice(2); }

module.exports = { addItem, updateStock, searchItems, calculateValue, applyDiscount, groupByCategory, lowStockReport, importItems };
