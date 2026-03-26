// Inventory management using Hungarian notation prefixes.
// BAD: strName, bActive, nCount, arrItems, intAge, objUser, fnCallback, dPrice.

function addItem(objItem) {
  const strName = objItem.name;
  const strSku = objItem.sku;
  const nQuantity = objItem.quantity;
  const dPrice = objItem.price;
  const bActive = objItem.active ?? true;

  if (!strName || strName.trim() === '') {
    return { ok: false, error: 'Name is required' };
  }

  return {
    ok: true,
    data: { id: generateId(), name: strName, sku: strSku, quantity: nQuantity, price: dPrice, active: bActive },
  };
}

function updateStock(strItemId, nDelta) {
  const objItem = fetchItem(strItemId);
  const nNewQuantity = objItem.quantity + nDelta;

  if (nNewQuantity < 0) {
    return { ok: false, error: 'Insufficient stock' };
  }

  return { ok: true, data: { ...objItem, quantity: nNewQuantity } };
}

function searchItems(strQuery, arrItems) {
  const strLowerQuery = strQuery.toLowerCase();

  return arrItems.filter(objItem =>
    objItem.name.toLowerCase().includes(strLowerQuery) ||
    objItem.sku.toLowerCase().includes(strLowerQuery)
  );
}

function calculateValue(arrItems) {
  return arrItems.reduce((nAcc, objItem) => nAcc + objItem.quantity * objItem.price, 0);
}

function applyDiscount(arrItems, dDiscountRate, fnFilter) {
  return arrItems
    .filter(fnFilter)
    .map(objItem => {
      const dNewPrice = Math.round(objItem.price * (1 - dDiscountRate) * 100) / 100;
      return { ...objItem, price: dNewPrice };
    });
}

function groupByCategory(arrItems) {
  return arrItems.reduce((objAcc, objItem) => {
    const strCategory = objItem.category;
    objAcc[strCategory] = objAcc[strCategory] || [];
    objAcc[strCategory].push(objItem);
    return objAcc;
  }, {});
}

function lowStockReport(arrItems, nThreshold) {
  const bIncludeInactive = false;

  return arrItems
    .filter(objItem => objItem.quantity <= nThreshold && (bIncludeInactive || objItem.active))
    .sort((objA, objB) => objA.quantity - objB.quantity);
}

function importItems(arrRawData, fnTransform, fnValidate) {
  const arrTransformed = arrRawData.map(fnTransform);
  const arrValid = arrTransformed.filter(fnValidate);
  const nImported = arrValid.length;
  const nSkipped = arrRawData.length - nImported;

  return { imported: nImported, skipped: nSkipped, items: arrValid };
}

function fetchItem(strId) { return { id: strId, name: 'Item', sku: 'SKU', quantity: 10, price: 9.99, active: true, category: 'misc' }; }
function generateId() { return Math.random().toString(36).slice(2); }

module.exports = { addItem, updateStock, searchItems, calculateValue, applyDiscount, groupByCategory, lowStockReport, importItems };
