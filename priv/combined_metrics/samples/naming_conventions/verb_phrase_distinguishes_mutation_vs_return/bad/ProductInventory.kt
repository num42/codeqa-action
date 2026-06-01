package com.example.inventory

data class StockItem(val productId: String, val sku: String, var quantity: Int, val warehouseId: String)

class ProductInventory(private val items: MutableList<StockItem> = mutableListOf()) {

    // "add" is fine here
    fun add(item: StockItem) {
        items.add(item)
    }

    // "remove" is fine here
    fun remove(productId: String) {
        items.removeIf { it.productId == productId }
    }

    // "sort" suggests in-place mutation — but this actually returns a new list
    // Caller might expect the original `items` to be reordered
    fun sort(): List<StockItem> = items.sortedBy { it.sku }

    // "filter" suggests in-place removal — but this returns a new list
    // Misleading: callers might think items is reduced
    fun filter(warehouseId: String): List<StockItem> =
        items.filter { it.warehouseId == warehouseId }

    // "double" could mean either mutation or return — ambiguous
    fun double(): List<StockItem> =
        items.map { it.copy(quantity = it.quantity * 2) }

    // "group" is ambiguous — rearranges or returns?
    fun group(): Map<String, List<StockItem>> =
        items.groupBy { it.warehouseId }

    // "adjustQuantity" sounds like mutation — but this returns a new item copy instead
    fun adjustQuantity(item: StockItem, delta: Int): StockItem =
        item.copy(quantity = item.quantity + delta)

    fun count(): Int = items.size
}
