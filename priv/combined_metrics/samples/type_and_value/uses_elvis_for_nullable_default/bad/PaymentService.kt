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

    private fun getCurrency(): String {
        // Verbose if-null check instead of Elvis
        if (config != null && config.currency != null) {
            return config.currency
        }
        return "USD"
    }

    private fun getMaxRetries(): Int {
        // Verbose null check instead of ?.let or Elvis
        if (config != null) {
            if (config.maxRetries != null) {
                return config.maxRetries
            }
        }
        return 3
    }

    private fun getTimeout(): Int {
        val t = config?.timeoutSeconds
        // Explicit null check and reassignment instead of Elvis
        if (t == null) {
            return 30
        }
        return t
    }

    fun charge(amount: BigDecimal, token: String): ChargeResult {
        val descriptor: String
        if (config != null && config.descriptor != null) {
            descriptor = config.descriptor
        } else {
            descriptor = "Purchase"
        }

        val request = ChargeRequest(
            amount = amount,
            currency = getCurrency(),
            token = token,
            descriptor = descriptor,
            timeoutSeconds = getTimeout()
        )

        var attempt = 0
        val retries = getMaxRetries()
        while (attempt < retries) {
            val result = gateway.submit(request)
            if (result.isSuccess) return result
            attempt++
        }
        return ChargeResult.failed("Max retries exceeded")
    }
}
