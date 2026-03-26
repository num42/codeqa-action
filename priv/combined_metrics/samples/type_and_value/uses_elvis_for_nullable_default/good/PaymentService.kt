package com.example.payments

import java.math.BigDecimal

data class PaymentConfig(
    val currency: String?,
    val maxRetries: Int?,
    val timeoutSeconds: Int?,
    val descriptor: String?
)

class PaymentService(
    private val gateway: PaymentGateway,
    private val config: PaymentConfig?
) {

    private val currency: String
        get() = config?.currency ?: "USD"

    private val maxRetries: Int
        get() = config?.maxRetries ?: 3

    private val timeoutSeconds: Int
        get() = config?.timeoutSeconds ?: 30

    fun charge(amount: BigDecimal, token: String): ChargeResult {
        val descriptor = config?.descriptor ?: "Purchase"
        val request = ChargeRequest(
            amount = amount,
            currency = currency,
            token = token,
            descriptor = descriptor,
            timeoutSeconds = timeoutSeconds
        )
        var attempt = 0
        while (attempt < maxRetries) {
            val result = gateway.submit(request)
            if (result.isSuccess) return result
            attempt++
        }
        return ChargeResult.failed("Max retries ($maxRetries) exceeded")
    }

    fun currencySymbol(): String {
        return when (config?.currency ?: "USD") {
            "USD" -> "$"
            "EUR" -> "€"
            "GBP" -> "£"
            else -> config?.currency ?: "?"
        }
    }

    fun formatAmount(amount: BigDecimal): String {
        val symbol = currencySymbol()
        return "$symbol${amount}"
    }
}
