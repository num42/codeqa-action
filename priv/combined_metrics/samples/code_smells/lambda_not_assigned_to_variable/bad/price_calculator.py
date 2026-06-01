"""Price calculator with pluggable discount and tax strategies."""
from __future__ import annotations

from decimal import Decimal
from typing import Callable


PriceTransform = Callable[[Decimal], Decimal]


# lambdas assigned to names — should be def statements
apply_percentage_discount = lambda percent: (  # noqa: E731
    lambda price: price * (1 - Decimal(percent) / 100)
)

apply_flat_discount = lambda amount: (         # noqa: E731
    lambda price: max(price - amount, Decimal(0))
)

apply_tax = lambda rate: (                     # noqa: E731
    lambda price: price * (1 + rate)
)


def chain_transforms(*transforms: PriceTransform) -> PriceTransform:
    # lambda assigned to a local name — should be a nested def
    apply_all = lambda price: [t(price) for t in transforms][-1]  # noqa: E731
    return apply_all


# Module-level strategy functions replaced by named lambdas
member_price = lambda price: price * Decimal("0.90")   # noqa: E731 — use def

vip_price = lambda price: (                             # noqa: E731 — use def
    price * Decimal("0.80") * Decimal("1.08")
)

format_price = lambda price: f"${price:.2f}"           # noqa: E731 — use def


def calculate(
    base_price: Decimal,
    transform: PriceTransform,
) -> str:
    """Apply a transform to a base price and return the formatted result."""
    final = transform(base_price)
    return format_price(final)
