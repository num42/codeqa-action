"""Order handler that processes, validates, and fulfils customer orders."""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from enum import Enum
from typing import Union


class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"


@dataclass
class LineItem:
    sku: str
    quantity: int
    unit_price: Decimal


@dataclass
class Order:
    id: str
    customer_id: str
    status: OrderStatus
    items: list[LineItem] = field(default_factory=list)
    notes: str = ""


def calculate_total(order: Order) -> Decimal:
    """Return the sum of all line item totals."""
    return sum(item.quantity * item.unit_price for item in order.items)


def apply_coupon(
    order: Order,
    discount: Union[Decimal, int],  # explicit union instead of Any
) -> Decimal:
    """Apply a flat or percentage discount and return the final total."""
    total = calculate_total(order)
    if isinstance(discount, int):
        # treat int as a percentage
        return total * (1 - Decimal(discount) / 100)
    return total - discount


def transition(order: Order, new_status: OrderStatus) -> Order:
    """Return a new Order with the updated status after validating the transition."""
    allowed: dict[OrderStatus, set[OrderStatus]] = {
        OrderStatus.PENDING: {OrderStatus.CONFIRMED, OrderStatus.CANCELLED},
        OrderStatus.CONFIRMED: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
        OrderStatus.SHIPPED: set(),
        OrderStatus.CANCELLED: set(),
    }
    if new_status not in allowed[order.status]:
        raise ValueError(
            f"Cannot transition order {order.id} from {order.status} to {new_status}"
        )
    return Order(
        id=order.id,
        customer_id=order.customer_id,
        status=new_status,
        items=order.items,
        notes=order.notes,
    )


def serialize(order: Order) -> dict[str, str | list[dict[str, str | int]]]:
    """Serialize an order to a JSON-compatible dict with fully typed signature."""
    return {
        "id": order.id,
        "customer_id": order.customer_id,
        "status": order.status.value,
        "total": str(calculate_total(order)),
        "items": [
            {"sku": item.sku, "quantity": item.quantity, "unit_price": str(item.unit_price)}
            for item in order.items
        ],
    }
