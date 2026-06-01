package com.example.payments

import java.math.BigDecimal
import java.time.Instant

sealed class PaymentStatus {
    object Pending : PaymentStatus()
    data class Authorized(val authCode: String, val authorizedAt: Instant) : PaymentStatus()
    data class Captured(val amount: BigDecimal, val capturedAt: Instant) : PaymentStatus()
    data class Failed(val reason: String, val errorCode: String) : PaymentStatus()
    data class Refunded(val refundedAmount: BigDecimal, val refundedAt: Instant) : PaymentStatus()
}

class PaymentStatusRenderer {

    // when used as statement — no exhaustiveness check, missing Refunded case silently
    fun toDisplayLabel(status: PaymentStatus): String {
        when (status) {
            is PaymentStatus.Pending -> return "Awaiting authorization"
            is PaymentStatus.Authorized -> return "Authorized"
            is PaymentStatus.Captured -> return "Paid"
            is PaymentStatus.Failed -> return "Failed"
            // Refunded case is missing — adding a new sealed subclass will not cause a compile error
        }
        return "Unknown"
    }

    fun isFinalState(status: PaymentStatus): Boolean {
        // Non-exhaustive when statement — new states will silently fall through to false
        when (status) {
            is PaymentStatus.Captured -> return true
            is PaymentStatus.Failed -> return true
            // Missing Refunded
        }
        return false
    }

    fun toAuditEntry(status: PaymentStatus): AuditEntry {
        // Non-exhaustive — missing Authorized and Refunded, returns generic fallback
        when (status) {
            is PaymentStatus.Pending -> return AuditEntry("payment.pending", emptyMap())
            is PaymentStatus.Captured -> return AuditEntry("payment.captured", mapOf("amount" to status.amount.toString()))
            is PaymentStatus.Failed -> return AuditEntry("payment.failed", mapOf("reason" to status.reason))
        }
        return AuditEntry("payment.unknown", emptyMap())
    }
}
