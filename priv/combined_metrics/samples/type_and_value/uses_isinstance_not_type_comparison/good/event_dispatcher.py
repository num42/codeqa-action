"""Event dispatcher that routes domain events to appropriate handlers."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass
class BaseEvent:
    occurred_at: datetime


@dataclass
class OrderPlacedEvent(BaseEvent):
    order_id: str
    customer_id: str


@dataclass
class PaymentReceivedEvent(BaseEvent):
    charge_id: str
    amount: float


@dataclass
class ShipmentDispatchedEvent(BaseEvent):
    shipment_id: str
    order_id: str
    tracking_number: str


def handle_order_placed(event: OrderPlacedEvent) -> str:
    return f"Order {event.order_id} placed by {event.customer_id}"


def handle_payment(event: PaymentReceivedEvent) -> str:
    return f"Payment {event.charge_id} received: ${event.amount:.2f}"


def handle_shipment(event: ShipmentDispatchedEvent) -> str:
    return f"Shipment {event.shipment_id} dispatched, tracking: {event.tracking_number}"


def dispatch(event: BaseEvent) -> str:
    """Route an event to its handler using isinstance — works with subclasses."""
    if isinstance(event, OrderPlacedEvent):
        return handle_order_placed(event)
    if isinstance(event, PaymentReceivedEvent):
        return handle_payment(event)
    if isinstance(event, ShipmentDispatchedEvent):
        return handle_shipment(event)
    raise ValueError(f"Unknown event type: {type(event).__name__}")


def is_financial_event(event: BaseEvent) -> bool:
    """Return True for any event related to money — isinstance covers subclasses."""
    return isinstance(event, PaymentReceivedEvent)


def filter_events(
    events: list[BaseEvent],
    event_type: type,
) -> list[BaseEvent]:
    """Return only events that are instances of the given type (or subclasses)."""
    return [e for e in events if isinstance(e, event_type)]
