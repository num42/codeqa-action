package com.example.inventory

data class StockItem(val productId: String, val sku: String, var quantity: Int, val warehouseId: String)

class ProductInventory(private val items: MutableList<StockItem> = mutableListOf()) {

    // Mutates the list in place — verb with no qualifier (imperative mood)
    fun add(item: StockItem) {
        items.add(item)
    }

    // Mutates the list in place — removes matching entry
    fun remove(productId: String) {
        items.removeIf { it.productId == productId }
    }

    // Mutates quantity of an existing item — imperative verb
    fun adjustQuantity(productId: String, delta: Int) {
        items.find { it.productId == productId }?.quantity =
            (items.find { it.productId == productId }?.quantity ?: 0) + delta
    }

    // Returns a new sorted list without touching the original — past-tense / adjective form
    fun sortedBySku(): List<StockItem> = items.sortedBy { it.sku }

    // Returns a new filtered list — past-tense form signals no mutation
    fun filteredByWarehouse(warehouseId: String): List<StockItem> =
        items.filter { it.warehouseId == warehouseId }

    // Returns a new list with quantities doubled — "doubled" signals a return value
    fun doubledQuantities(): List<StockItem> =
        items.map { it.copy(quantity = it.quantity * 2) }

    // Returns a transformed snapshot — "grouped" signals a new structure returned
    fun groupedByWarehouse(): Map<String, List<StockItem>> =
        items.groupBy { it.warehouseId }

    fun count(): Int = items.size
}
