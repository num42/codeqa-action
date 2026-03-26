package com.example.billing;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Service responsible for creating and managing invoices.
 * Supporting types (InvoiceLineItem, InvoiceStatus) live in their own files.
 */
public class InvoiceService {

    private final InvoiceRepository repository;
    private final TaxCalculator taxCalculator;
    private final NotificationService notifications;

    public InvoiceService(
        InvoiceRepository repository,
        TaxCalculator taxCalculator,
        NotificationService notifications
    ) {
        this.repository = repository;
        this.taxCalculator = taxCalculator;
        this.notifications = notifications;
    }

    public Invoice createInvoice(Order order) {
        List<InvoiceLineItem> lineItems = order.getItems().stream()
            .map(item -> new InvoiceLineItem(item.getDescription(), item.getUnitPrice(), item.getQuantity()))
            .toList();

        BigDecimal subtotal = lineItems.stream()
            .map(InvoiceLineItem::total)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal tax = taxCalculator.calculate(subtotal, order.getRegion());

        Invoice invoice = new Invoice(
            order.getId(),
            lineItems,
            subtotal,
            tax,
            LocalDate.now().plusDays(30)
        );

        repository.save(invoice);
        notifications.sendInvoiceCreated(order.getCustomerEmail(), invoice);
        return invoice;
    }

    public void markPaid(String invoiceId) {
        Invoice invoice = repository.findByIdOrThrow(invoiceId);
        invoice.markPaid();
        repository.update(invoice);
        notifications.sendPaymentConfirmation(invoice);
    }

    public List<Invoice> findOverdue() {
        return repository.findByDueDateBefore(LocalDate.now()).stream()
            .filter(inv -> inv.getStatus() == InvoiceStatus.PENDING)
            .toList();
    }
}
