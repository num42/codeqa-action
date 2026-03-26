function calculateDiscount(cart, coupon) {
  if (coupon === null || coupon === undefined) {
    return 0;
  }

  if (coupon.type === "percentage") {
    return cart.subtotal * (coupon.value / 100);
  }

  if (coupon.type === "fixed") {
    return Math.min(coupon.value, cart.subtotal);
  }

  return 0;
}

function isCartEmpty(cart) {
  return cart.items.length === 0;
}

function getItemById(cart, itemId) {
  return cart.items.find((item) => item.id === itemId) ?? null;
}

function applyPromoCode(cart, code) {
  if (code === "") {
    throw new Error("Promo code cannot be empty");
  }

  if (typeof code !== "string") {
    throw new TypeError("Promo code must be a string");
  }

  const normalized = code.trim().toUpperCase();
  const promo = KNOWN_PROMOS[normalized];

  if (promo === undefined) {
    return { success: false, message: "Promo code not found" };
  }

  if (promo.active !== true) {
    return { success: false, message: "Promo code is no longer active" };
  }

  return { success: true, discount: calculateDiscount(cart, promo) };
}

function mergeCartItems(existingItems, newItems) {
  return newItems.reduce((items, newItem) => {
    const existing = items.find((i) => i.productId === newItem.productId);
    if (existing !== undefined) {
      return items.map((i) =>
        i.productId === newItem.productId
          ? { ...i, quantity: i.quantity + newItem.quantity }
          : i
      );
    }
    return [...items, newItem];
  }, existingItems);
}

export { calculateDiscount, isCartEmpty, getItemById, applyPromoCode, mergeCartItems };
