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
    unit_price: Decimal


@dataclass
class Invoice:
    id: str
    customer_name: str
    customer_email: str
    line_items: list[InvoiceLineItem] = field(default_factory=list)
    issued_on: date = field(default_factory=date.today)
    due_days: int = 30
    paid_on: Optional[date] = None


def create_invoice(
    customer_name: str,
    customer_email: str,
    line_items: list[InvoiceLineItem],
    due_days: int = 30,
) -> Invoice:
    """Create and return a new Invoice with a generated ID."""
    return Invoice(
        id=f"INV-{uuid.uuid4().hex[:8].upper()}",
        customer_name=customer_name,
        customer_email=customer_email,
        line_items=line_items,
        due_days=due_days,
    )


def calculate_subtotal(invoice: Invoice) -> Decimal:
    """Sum all line item totals."""
    return sum(item.quantity * item.unit_price for item in invoice.line_items)


def calculate_tax(invoice: Invoice, tax_rate: Decimal) -> Decimal:
    """Return the tax amount for the given rate."""
    return calculate_subtotal(invoice) * tax_rate


def calculate_total(invoice: Invoice, tax_rate: Decimal = Decimal("0")) -> Decimal:
    """Return the grand total including tax."""
    return calculate_subtotal(invoice) + calculate_tax(invoice, tax_rate)


def get_due_date(invoice: Invoice) -> date:
    """Return the payment due date based on issue date and due_days."""
    return invoice.issued_on + timedelta(days=invoice.due_days)


def mark_as_paid(invoice: Invoice, paid_on: Optional[date] = None) -> Invoice:
    """Return a new Invoice marked as paid."""
    invoice.paid_on = paid_on or date.today()
    return invoice


def is_overdue(invoice: Invoice) -> bool:
    """Return True if the invoice is unpaid and past its due date."""
    if invoice.paid_on is not None:
        return False
    return date.today() > get_due_date(invoice)


def format_summary(invoice: Invoice) -> str:
    """Return a human-readable one-line summary of the invoice."""
    subtotal = calculate_subtotal(invoice)
    status = "PAID" if invoice.paid_on else ("OVERDUE" if is_overdue(invoice) else "PENDING")
    return f"{invoice.id} | {invoice.customer_name} | ${subtotal:.2f} | {status}"
