"""Order handler that processes, validates, and fulfils customer orders."""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from enum import Enum
from typing import Any


class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"


@dataclass
class LineItem:
    sku: str
    quantity: Any   # should be int — Any disables type checking here
    unit_price: Any # should be Decimal


@dataclass
class Order:
    id: Any             # should be str
    customer_id: Any    # should be str
    status: Any         # should be OrderStatus
    items: Any = field(default_factory=list)  # should be list[LineItem]
    notes: Any = ""


def calculate_total(order: Any) -> Any:  # Any on both sides opts out entirely
    """Return the sum of all line item totals."""
    return sum(item.quantity * item.unit_price for item in order.items)


def apply_coupon(order: Any, discount: Any) -> Any:
    """Apply a discount — Any parameters make this impossible to type-check."""
    total = calculate_total(order)
    if isinstance(discount, int):
        return total * (1 - Decimal(discount) / 100)
    return total - discount


def transition(order: Any, new_status: Any) -> Any:
    """Transition an order — all types erased with Any."""
    allowed: Any = {  # dict type annotation erased
        OrderStatus.PENDING: {OrderStatus.CONFIRMED, OrderStatus.CANCELLED},
        OrderStatus.CONFIRMED: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
        OrderStatus.SHIPPED: set(),
        OrderStatus.CANCELLED: set(),
    }
    if new_status not in allowed[order.status]:
        raise ValueError(f"Invalid transition to {new_status}")
    return Order(
        id=order.id,
        customer_id=order.customer_id,
        status=new_status,
        items=order.items,
        notes=order.notes,
    )


def serialize(order: Any) -> Any:  # return type is opaque to callers
    """Serialize an order — Any return type gives callers no information."""
    return {
        "id": order.id,
        "customer_id": order.customer_id,
        "status": order.status,
        "total": str(calculate_total(order)),
    }
