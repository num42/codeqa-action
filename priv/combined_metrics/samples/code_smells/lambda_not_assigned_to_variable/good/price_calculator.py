"""Price calculator with pluggable discount and tax strategies."""
from __future__ import annotations

from decimal import Decimal
from typing import Callable


PriceTransform = Callable[[Decimal], Decimal]


def apply_percentage_discount(percent: int) -> PriceTransform:
    """Return a function that applies a percentage discount to a price."""
    def discount(price: Decimal) -> Decimal:
        return price * (1 - Decimal(percent) / 100)
    return discount


def apply_flat_discount(amount: Decimal) -> PriceTransform:
    """Return a function that subtracts a flat amount from a price."""
    def discount(price: Decimal) -> Decimal:
        return max(price - amount, Decimal(0))
    return discount


def apply_tax(rate: Decimal) -> PriceTransform:
    """Return a function that adds a tax rate to a price."""
    def add_tax(price: Decimal) -> Decimal:
        return price * (1 + rate)
    return add_tax


def chain_transforms(*transforms: PriceTransform) -> PriceTransform:
    """Combine multiple price transforms into a single function."""
    def apply_all(price: Decimal) -> Decimal:
        for transform in transforms:
            price = transform(price)
        return price
    return apply_all


def format_price(price: Decimal) -> str:
    """Format a Decimal price as a currency string."""
    return f"${price:.2f}"


def calculate(
    base_price: Decimal,
    transform: PriceTransform,
) -> str:
    """Apply a transform to a base price and return the formatted result."""
    final = transform(base_price)
    return format_price(final)


# Module-level strategies defined as proper named functions, not lambdas
def member_price(price: Decimal) -> Decimal:
    """10 % member discount."""
    return price * Decimal("0.90")


def vip_price(price: Decimal) -> Decimal:
    """20 % VIP discount followed by 8 % tax."""
    discounted = price * Decimal("0.80")
    return discounted * Decimal("1.08")
