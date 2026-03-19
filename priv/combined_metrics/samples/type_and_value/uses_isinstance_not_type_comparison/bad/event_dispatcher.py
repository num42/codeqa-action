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
    """Route an event — type() == fails for subclasses, unlike isinstance."""
    if type(event) == OrderPlacedEvent:        # fails if someone subclasses OrderPlacedEvent
        return handle_order_placed(event)
    if type(event) == PaymentReceivedEvent:    # same issue
        return handle_payment(event)
    if type(event) == ShipmentDispatchedEvent: # same issue
        return handle_shipment(event)
    raise ValueError(f"Unknown event type: {type(event).__name__}")


def is_financial_event(event: BaseEvent) -> bool:
    """type() comparison breaks polymorphism."""
    return type(event) == PaymentReceivedEvent   # won't match subclasses


def filter_events(events: list[BaseEvent], event_type: type) -> list[BaseEvent]:
    """Filter using exact type match — subclass instances are silently excluded."""
    return [e for e in events if type(e) == event_type]
