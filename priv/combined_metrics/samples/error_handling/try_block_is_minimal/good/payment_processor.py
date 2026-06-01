"""Payment processor that charges customers and records transactions."""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Optional
import uuid


class PaymentGatewayError(Exception):
    """Raised when the external gateway rejects a charge."""


@dataclass
class PaymentIntent:
    amount: Decimal
    currency: str
    customer_id: str
    description: str


@dataclass
class ChargeResult:
    charge_id: str
    amount: Decimal
    currency: str
    customer_id: str


def _call_gateway(intent: PaymentIntent) -> str:
    """Simulate an external gateway call; returns a charge ID."""
    if intent.amount <= 0:
        raise PaymentGatewayError("Amount must be positive")
    return f"ch_{uuid.uuid4().hex[:16]}"


def _record_transaction(charge_id: str, intent: PaymentIntent) -> None:
    """Persist the transaction record (simulated)."""
    print(f"[DB] recorded charge {charge_id} for customer {intent.customer_id}")


def charge(intent: PaymentIntent) -> ChargeResult:
    """Charge a customer, keeping the try block as small as possible.

    Only the gateway call is inside try; recording and building the result
    happen outside so any errors there surface with a clean traceback.
    """
    try:
        charge_id = _call_gateway(intent)   # only the risky call is in try
    except PaymentGatewayError as exc:
        raise PaymentGatewayError(
            f"Gateway rejected charge for customer {intent.customer_id}: {exc}"
        ) from exc

    # safe operations live outside the try block
    _record_transaction(charge_id, intent)

    return ChargeResult(
        charge_id=charge_id,
        amount=intent.amount,
        currency=intent.currency,
        customer_id=intent.customer_id,
    )


def refund(charge_id: str, amount: Optional[Decimal] = None) -> bool:
    """Issue a refund — try wraps only the gateway call."""
    try:
        # only the I/O-bound, failure-prone call belongs inside try
        success = charge_id.startswith("ch_")  # simulated gateway call
    except AttributeError as exc:
        raise ValueError(f"Invalid charge_id: {charge_id!r}") from exc

    if not success:
        raise PaymentGatewayError(f"Refund rejected for charge {charge_id}")

    print(f"[DB] recorded refund for {charge_id} amount={amount}")
    return True
