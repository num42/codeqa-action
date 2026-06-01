package com.example.cart

import java.math.BigDecimal

data class CartItem(val productId: String, val name: String, val price: BigDecimal, val quantity: Int)

class ShoppingCart(private val userId: String) {

    private val _items = mutableListOf<CartItem>()
    private val _appliedCoupons = mutableSetOf<String>()

    // Exposed as immutable List — callers cannot mutate internal state
    val items: List<CartItem> get() = _items.toList()

    // Exposed as immutable Set
    val appliedCoupons: Set<String> get() = _appliedCoupons.toSet()

    fun addItem(item: CartItem) {
        val existing = _items.indexOfFirst { it.productId == item.productId }
        if (existing >= 0) {
            _items[existing] = _items[existing].copy(quantity = _items[existing].quantity + item.quantity)
        } else {
            _items.add(item)
        }
    }

    fun removeItem(productId: String) {
        _items.removeIf { it.productId == productId }
    }

    fun applyCoupon(code: String) {
        _appliedCoupons.add(code.uppercase())
    }

    // Returns immutable collection — caller gets a snapshot
    fun itemsAbovePrice(threshold: BigDecimal): List<CartItem> {
        return _items.filter { it.price > threshold }
    }

    // Map exposed as immutable — no one can add keys outside this class
    fun itemsByProductId(): Map<String, CartItem> {
        return _items.associateBy { it.productId }
    }

    fun total(): BigDecimal {
        return _items.fold(BigDecimal.ZERO) { acc, item ->
            acc + item.price.multiply(BigDecimal.valueOf(item.quantity.toLong()))
        }
    }
}
