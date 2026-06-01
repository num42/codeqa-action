package com.example.cart

import java.math.BigDecimal

data class CartItem(val productId: String, val name: String, val price: BigDecimal, val quantity: Int)

class ShoppingCart(private val userId: String) {

    // Exposing MutableList directly — callers can mutate internal state without going through class methods
    val items: MutableList<CartItem> = mutableListOf()

    // Exposing MutableSet directly
    val appliedCoupons: MutableSet<String> = mutableSetOf()

    fun addItem(item: CartItem) {
        val existing = items.indexOfFirst { it.productId == item.productId }
        if (existing >= 0) {
            items[existing] = items[existing].copy(quantity = items[existing].quantity + item.quantity)
        } else {
            items.add(item)
        }
    }

    fun removeItem(productId: String) {
        items.removeIf { it.productId == productId }
    }

    fun applyCoupon(code: String) {
        appliedCoupons.add(code.uppercase())
    }

    // Returns MutableList — caller can modify the filtered snapshot and it looks authoritative
    fun itemsAbovePrice(threshold: BigDecimal): MutableList<CartItem> {
        return items.filter { it.price > threshold }.toMutableList()
    }

    // Returns MutableMap — callers could add/remove entries thinking it affects the cart
    fun itemsByProductId(): MutableMap<String, CartItem> {
        return items.associateByTo(mutableMapOf()) { it.productId }
    }

    fun total(): BigDecimal {
        return items.fold(BigDecimal.ZERO) { acc, item ->
            acc + item.price.multiply(BigDecimal.valueOf(item.quantity.toLong()))
        }
    }
}
