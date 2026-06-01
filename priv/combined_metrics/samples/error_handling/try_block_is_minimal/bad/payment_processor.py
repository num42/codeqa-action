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
    if intent.amount <= 0:
        raise PaymentGatewayError("Amount must be positive")
    return f"ch_{uuid.uuid4().hex[:16]}"


def _record_transaction(charge_id: str, intent: PaymentIntent) -> None:
    print(f"[DB] recorded charge {charge_id} for customer {intent.customer_id}")


def charge(intent: PaymentIntent) -> Optional[ChargeResult]:
    """Charge a customer — oversized try block hides bugs in safe code."""
    try:
        # gateway call AND all subsequent safe operations crammed into one try block
        charge_id = _call_gateway(intent)

        # if _record_transaction raises (e.g. DB error), it's caught as PaymentGatewayError
        _record_transaction(charge_id, intent)

        # building the result struct is also in try — bugs here are misattributed
        result = ChargeResult(
            charge_id=charge_id,
            amount=intent.amount,
            currency=intent.currency,
            customer_id=intent.customer_id,
        )
        return result
    except PaymentGatewayError as exc:
        print(f"charge failed: {exc}")
        return None


def refund(charge_id: str, amount: Optional[Decimal] = None) -> bool:
    """Issue a refund — the try block swallows errors from multiple unrelated steps."""
    try:
        # all three steps are wrapped together; an error in any one blames the gateway
        is_valid = charge_id.startswith("ch_")
        if not is_valid:
            raise PaymentGatewayError(f"Refund rejected for charge {charge_id}")
        print(f"[DB] recorded refund for {charge_id} amount={amount}")
        return True
    except PaymentGatewayError as exc:
        print(f"refund failed: {exc}")
        return False
