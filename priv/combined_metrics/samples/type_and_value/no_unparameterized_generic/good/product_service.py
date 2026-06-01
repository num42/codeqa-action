"""Product service managing catalogue items, pricing tiers, and inventory."""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Optional


@dataclass
class PricingTier:
    name: str
    multiplier: Decimal


@dataclass
class Product:
    id: str
    name: str
    base_price: Decimal
    tags: list[str] = field(default_factory=list)
    attributes: dict[str, str] = field(default_factory=dict)


def find_by_tags(
    products: list[Product],
    tags: set[str],
) -> list[Product]:
    """Return products that have at least one matching tag."""
    return [p for p in products if set(p.tags) & tags]


def build_price_map(
    products: list[Product],
    tier: PricingTier,
) -> dict[str, Decimal]:
    """Return a mapping of product ID to adjusted price for the given tier."""
    return {p.id: p.base_price * tier.multiplier for p in products}


def group_by_attribute(
    products: list[Product],
    attribute_key: str,
) -> dict[str, list[Product]]:
    """Group products by the value of a given attribute key."""
    groups: dict[str, list[Product]] = {}
    for product in products:
        value = product.attributes.get(attribute_key, "")
        groups.setdefault(value, []).append(product)
    return groups


def summarise_inventory(
    stock: dict[str, int],
    products: list[Product],
) -> list[dict[str, str | int | Decimal]]:
    """Combine stock counts with product data into summary records."""
    index: dict[str, Product] = {p.id: p for p in products}
    return [
        {
            "id": product_id,
            "name": index[product_id].name,
            "quantity": quantity,
            "total_value": index[product_id].base_price * quantity,
        }
        for product_id, quantity in stock.items()
        if product_id in index
    ]


def apply_bulk_discount(
    prices: dict[str, Decimal],
    discount_ids: set[str],
    percent: int,
) -> dict[str, Decimal]:
    """Return a new price map with discounts applied to the specified IDs."""
    factor = Decimal(1) - Decimal(percent) / 100
    return {
        pid: (price * factor if pid in discount_ids else price)
        for pid, price in prices.items()
    }
