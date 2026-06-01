defmodule Test.Fixtures.JavaScript.ShoppingCart do
  @moduledoc false
  use Test.LanguageFixture, language: "javascript shopping_cart"

  @code ~S'''
  class CartItem {
    constructor(id, name, price, quantity) {
      this.id = id;
      this.name = name;
      this.price = price;
      this.quantity = quantity;
    }

    get subtotal() {
      return this.price * this.quantity;
    }

    withQuantity(quantity) {
      return new CartItem(this.id, this.name, this.price, quantity);
    }
  }

  class Discount {
    constructor(code, type, value) {
      this.code = code;
      this.type = type;
      this.value = value;
    }

    apply(subtotal) {
      if (this.type === "percent") {
        return subtotal * (1 - this.value / 100);
      }
      if (this.type === "fixed") {
        return Math.max(0, subtotal - this.value);
      }
      return subtotal;
    }
  }

  class ShoppingCart {
    constructor() {
      this._items = new Map();
      this._discount = null;
      this._listeners = [];
    }

    addItem(item) {
      var existing = this._items.get(item.id);
      if (existing) {
        this._items.set(item.id, existing.withQuantity(existing.quantity + item.quantity));
      } else {
        this._items.set(item.id, item);
      }
      this._emit("item:added", item);
      return this;
    }

    removeItem(id) {
      this._items.delete(id);
      this._emit("item:removed", { id: id });
      return this;
    }

    applyDiscount(discount) {
      this._discount = discount;
      this._emit("discount:applied", discount);
      return this;
    }

    get subtotal() {
      var total = 0;
      this._items.forEach(function(item) { total += item.subtotal; });
      return total;
    }

    get total() {
      var sub = this.subtotal;
      return this._discount ? this._discount.apply(sub) : sub;
    }

    get itemCount() {
      var count = 0;
      this._items.forEach(function(item) { count += item.quantity; });
      return count;
    }

    on(event, handler) {
      this._listeners.push({ event: event, handler: handler });
      return this;
    }

    _emit(event, data) {
      this._listeners
        .filter(function(l) { return l.event === event; })
        .forEach(function(l) { l.handler(data); });
    }
  }
  '''
end
