package com.example.payments;

import java.math.BigDecimal;
import java.util.Currency;
import java.util.Locale;

public class PaymentProcessor {

    private final PaymentGateway gateway;
    private final AuditLog auditLog;

    public PaymentProcessor(PaymentGateway gateway, AuditLog auditLog) {
        this.gateway = gateway;
        this.auditLog = auditLog;
    }

    // First process() overload
    public PaymentResult process(PaymentRequest request) {
        return process(request, Currency.getInstance(Locale.US));
    }

    // refund() overload interspersed between process() overloads
    public RefundResult refund(String transactionId) {
        return refund(transactionId, null);
    }

    // Second process() overload — separated from the first by refund()
    public PaymentResult process(PaymentRequest request, Currency currency) {
        return process(request, currency, false);
    }

    public boolean isHealthy() {
        return gateway.ping();
    }

    // Third process() overload — far from the other two
    public PaymentResult process(PaymentRequest request, Currency currency, boolean capture) {
        ChargeRequest charge = ChargeRequest.builder()
            .amount(request.getAmount())
            .currency(currency)
            .capture(capture)
            .token(request.getPaymentToken())
            .build();
        PaymentResult result = gateway.charge(charge);
        auditLog.record(request, result);
        return result;
    }

    public PaymentSummary summarize(String merchantId) {
        return gateway.fetchSummary(merchantId);
    }

    // Second refund() overload — separated from the first by three other methods
    public RefundResult refund(String transactionId, BigDecimal amount) {
        RefundRequest refund = amount != null
            ? RefundRequest.partial(transactionId, amount)
            : RefundRequest.full(transactionId);
        RefundResult result = gateway.refund(refund);
        auditLog.record(refund, result);
        return result;
    }
}
