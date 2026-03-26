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

    // All process() overloads are grouped together
    public PaymentResult process(PaymentRequest request) {
        return process(request, Currency.getInstance(Locale.US));
    }

    public PaymentResult process(PaymentRequest request, Currency currency) {
        return process(request, currency, false);
    }

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

    // All refund() overloads are grouped together
    public RefundResult refund(String transactionId) {
        return refund(transactionId, null);
    }

    public RefundResult refund(String transactionId, BigDecimal amount) {
        RefundRequest refund = amount != null
            ? RefundRequest.partial(transactionId, amount)
            : RefundRequest.full(transactionId);
        RefundResult result = gateway.refund(refund);
        auditLog.record(refund, result);
        return result;
    }

    public boolean isHealthy() {
        return gateway.ping();
    }

    public PaymentSummary summarize(String merchantId) {
        return gateway.fetchSummary(merchantId);
    }
}
