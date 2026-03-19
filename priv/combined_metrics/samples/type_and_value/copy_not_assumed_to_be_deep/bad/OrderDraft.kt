package com.example.orders

import java.math.BigDecimal

data class LineItem(val productId: String, var quantity: Int, val unitPrice: BigDecimal)

data class OrderDraft(
    val customerId: String,
    val items: MutableList<LineItem>,
    val notes: String?
)

class OrderDraftService {

    /**
     * Assumes copy() performs a deep copy — it does not.
     * Both `draft` and the returned copy share the same `items` MutableList reference.
     */
    fun withPromoItems(draft: OrderDraft, promoProductId: String): OrderDraft {
        // copy() is SHALLOW — promoCopy.items and draft.items point to the same list
        val promoCopy = draft.copy()
        promoCopy.items.add(LineItem(promoProductId, 1, BigDecimal.ZERO))
        // This mutation also affects the original draft!
        return promoCopy
    }

    /**
     * Modifies quantity on the "copy" — but since items list is shared,
     * this also mutates the original.
     */
    fun withAdjustedQuantity(draft: OrderDraft, productId: String, newQty: Int): OrderDraft {
        val adjusted = draft.copy()  // shallow copy only
        adjusted.items.find { it.productId == productId }?.quantity = newQty
        // Mutates the original draft's items as well
        return adjusted
    }

    /**
     * Attempts to snapshot for audit, believing copy() isolates state.
     * Both the live draft and this "snapshot" share the same mutable items list.
     */
    fun snapshot(draft: OrderDraft): OrderDraft {
        return draft.copy()  // NOT a deep copy — shared mutable state
    }
}
