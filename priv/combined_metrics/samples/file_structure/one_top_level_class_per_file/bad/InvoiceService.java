package com.example.billing;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

// Multiple top-level class declarations in a single file

public class InvoiceService {

    private final InvoiceRepository repository;
    private final TaxCalculator taxCalculator;

    public InvoiceService(InvoiceRepository repository, TaxCalculator taxCalculator) {
        this.repository = repository;
        this.taxCalculator = taxCalculator;
    }

    public Invoice createInvoice(Order order) {
        List<InvoiceLineItem> lineItems = order.getItems().stream()
            .map(item -> new InvoiceLineItem(item.getDescription(), item.getUnitPrice(), item.getQuantity()))
            .toList();
        return new Invoice(order.getId(), lineItems, LocalDate.now().plusDays(30));
    }
}

// Second top-level class in the same file — violates the one-class-per-file rule
class InvoiceLineItem {
    private final String description;
    private final BigDecimal unitPrice;
    private final int quantity;

    public InvoiceLineItem(String description, BigDecimal unitPrice, int quantity) {
        this.description = description;
        this.unitPrice = unitPrice;
        this.quantity = quantity;
    }

    public BigDecimal total() {
        return unitPrice.multiply(BigDecimal.valueOf(quantity));
    }

    public String getDescription() { return description; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public int getQuantity() { return quantity; }
}

// Third top-level class in the same file
class InvoiceValidator {
    public boolean isValid(Invoice invoice) {
        return invoice != null
            && invoice.getId() != null
            && !invoice.getLineItems().isEmpty();
    }
}
