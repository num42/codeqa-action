package com.example.orders

import java.math.BigDecimal

data class LineItem(val productId: String, var quantity: Int, val unitPrice: BigDecimal)

data class OrderDraft(
    val customerId: String,
    val items: List<LineItem>,   // List, not MutableList — prevents external mutation
    val notes: String?
)

class OrderDraftService {

    /**
     * Creates a promotional copy of the draft with an explicit deep copy of items,
     * because copy() only shallow-copies the list reference.
     */
    fun withPromoItems(draft: OrderDraft, promoProductId: String): OrderDraft {
        // Deep copy items list explicitly — copy() would share the same list object
        val newItems = draft.items.map { it.copy() } + LineItem(promoProductId, 1, BigDecimal.ZERO)
        return draft.copy(items = newItems)
    }

    /**
     * Applies a quantity adjustment. Uses an explicit deep copy so the original draft is untouched.
     */
    fun withAdjustedQuantity(draft: OrderDraft, productId: String, newQty: Int): OrderDraft {
        // Explicitly rebuilding the items list — not assuming copy() is deep
        val updatedItems = draft.items.map { item ->
            if (item.productId == productId) item.copy(quantity = newQty) else item.copy()
        }
        return draft.copy(items = updatedItems)
    }

    /**
     * Snapshots the draft for audit purposes — explicitly materialises new item instances
     * so the audit record is fully independent from any future mutations of the source.
     */
    fun snapshot(draft: OrderDraft): OrderDraft {
        return OrderDraft(
            customerId = draft.customerId,
            items = draft.items.map { it.copy() },  // explicit deep copy
            notes = draft.notes
        )
    }
}
