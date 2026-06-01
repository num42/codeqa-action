package com.example.pricing

import java.math.BigDecimal
import java.util.Currency
import java.util.Locale

/**
 * Formats monetary amounts for display in various locales and currencies.
 * Named after what it does — not a meaningless "Util" or "Helper".
 */
class PriceFormatter(private val locale: Locale = Locale.US) {

    fun format(amount: BigDecimal, currency: Currency): String {
        val symbol = currency.getSymbol(locale)
        val formatted = amount.setScale(currency.defaultFractionDigits, java.math.RoundingMode.HALF_UP)
        return "$symbol$formatted"
    }

    fun formatWithCode(amount: BigDecimal, currency: Currency): String {
        val formatted = format(amount, currency)
        return "$formatted ${currency.currencyCode}"
    }

    fun formatRange(low: BigDecimal, high: BigDecimal, currency: Currency): String {
        return "${format(low, currency)} – ${format(high, currency)}"
    }
}

/**
 * Validates pricing rules for products.
 * Named after its specific responsibility.
 */
class PriceValidator {

    fun isValidRetailPrice(price: BigDecimal): Boolean =
        price > BigDecimal.ZERO && price <= BigDecimal("99999.99")

    fun isBelowCost(price: BigDecimal, costPrice: BigDecimal): Boolean =
        price < costPrice

    fun isReasonableDiscount(original: BigDecimal, discounted: BigDecimal): Boolean {
        if (original <= BigDecimal.ZERO) return false
        val discountPct = (original - discounted).divide(original) * BigDecimal("100")
        return discountPct in BigDecimal.ZERO..BigDecimal("80")
    }
}
