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

    // when used as expression — all cases must be covered (exhaustive)
    fun toDisplayLabel(status: PaymentStatus): String = when (status) {
        is PaymentStatus.Pending -> "Awaiting authorization"
        is PaymentStatus.Authorized -> "Authorized (${status.authCode})"
        is PaymentStatus.Captured -> "Paid"
        is PaymentStatus.Failed -> "Failed: ${status.reason}"
        is PaymentStatus.Refunded -> "Refunded"
    }

    fun isFinalState(status: PaymentStatus): Boolean = when (status) {
        is PaymentStatus.Captured,
        is PaymentStatus.Failed,
        is PaymentStatus.Refunded -> true
        is PaymentStatus.Pending,
        is PaymentStatus.Authorized -> false
    }

    fun toAuditEntry(status: PaymentStatus): AuditEntry = when (status) {
        is PaymentStatus.Pending -> AuditEntry("payment.pending", emptyMap())
        is PaymentStatus.Authorized -> AuditEntry("payment.authorized", mapOf("code" to status.authCode))
        is PaymentStatus.Captured -> AuditEntry("payment.captured", mapOf("amount" to status.amount.toString()))
        is PaymentStatus.Failed -> AuditEntry("payment.failed", mapOf("reason" to status.reason, "code" to status.errorCode))
        is PaymentStatus.Refunded -> AuditEntry("payment.refunded", mapOf("amount" to status.refundedAmount.toString()))
    }
}
