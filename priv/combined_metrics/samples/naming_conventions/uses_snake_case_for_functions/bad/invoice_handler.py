"""Invoice handler that generates, validates, and sends customer invoices."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal
from typing import Optional
import uuid


@dataclass
class InvoiceLineItem:
    description: str
    quantity: int
    unitPrice: Decimal        # camelCase field — should be unit_price


@dataclass
class Invoice:
    id: str
    customerName: str         # camelCase — should be customer_name
    customerEmail: str        # camelCase — should be customer_email
    lineItems: list = field(default_factory=list)  # camelCase — should be line_items
    issuedOn: date = field(default_factory=date.today)
    dueDays: int = 30
    paidOn: Optional[date] = None


def createInvoice(                   # camelCase function — should be create_invoice
    customerName: str,
    customerEmail: str,
    lineItems: list,
    dueDays: int = 30,
) -> Invoice:
    return Invoice(
        id=f"INV-{uuid.uuid4().hex[:8].upper()}",
        customerName=customerName,
        customerEmail=customerEmail,
        lineItems=lineItems,
        dueDays=dueDays,
    )


def calculateSubtotal(invoice: Invoice) -> Decimal:  # camelCase — should be calculate_subtotal
    return sum(item.quantity * item.unitPrice for item in invoice.lineItems)


def calculateTax(invoice: Invoice, taxRate: Decimal) -> Decimal:  # camelCase params too
    return calculateSubtotal(invoice) * taxRate


def calculateTotal(invoice: Invoice, taxRate: Decimal = Decimal("0")) -> Decimal:
    return calculateSubtotal(invoice) + calculateTax(invoice, taxRate)


def getDueDate(invoice: Invoice) -> date:           # camelCase — should be get_due_date
    return invoice.issuedOn + timedelta(days=invoice.dueDays)


def markAsPaid(invoice: Invoice, paidOn: Optional[date] = None) -> Invoice:
    invoice.paidOn = paidOn or date.today()
    return invoice


def isOverdue(invoice: Invoice) -> bool:            # camelCase — should be is_overdue
    if invoice.paidOn is not None:
        return False
    return date.today() > getDueDate(invoice)


def formatSummary(invoice: Invoice) -> str:         # camelCase — should be format_summary
    subtotal = calculateSubtotal(invoice)
    status = "PAID" if invoice.paidOn else ("OVERDUE" if isOverdue(invoice) else "PENDING")
    return f"{invoice.id} | {invoice.customerName} | ${subtotal:.2f} | {status}"
