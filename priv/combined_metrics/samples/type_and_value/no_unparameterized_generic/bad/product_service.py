"""Product service managing catalogue items, pricing tiers, and inventory."""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Dict, List, Set  # old-style imports, unparameterized below


@dataclass
class PricingTier:
    name: str
    multiplier: Decimal


@dataclass
class Product:
    id: str
    name: str
    base_price: Decimal
    tags: List = field(default_factory=list)        # bare List — implies List[Any]
    attributes: Dict = field(default_factory=dict)  # bare Dict — implies Dict[Any, Any]


def find_by_tags(
    products: List,       # bare List — what kind of items?
    tags: Set,            # bare Set — what kind of elements?
) -> List:               # bare List — return element type unknown
    """Return products that have at least one matching tag."""
    return [p for p in products if set(p.tags) & tags]


def build_price_map(
    products: List,       # bare List
    tier: PricingTier,
) -> Dict:               # bare Dict — key/value types unknown to type checker
    """Return a mapping of product ID to adjusted price for the given tier."""
    return {p.id: p.base_price * tier.multiplier for p in products}


def group_by_attribute(
    products: List,       # bare List
    attribute_key: str,
) -> Dict:               # bare Dict — caller cannot know it's Dict[str, List[Product]]
    """Group products by the value of a given attribute key."""
    groups: Dict = {}    # bare Dict annotation
    for product in products:
        value = product.attributes.get(attribute_key, "")
        groups.setdefault(value, []).append(product)
    return groups


def summarise_inventory(
    stock: Dict,          # bare Dict — key/value types invisible
    products: List,       # bare List
) -> List:               # bare List
    index: Dict = {p.id: p for p in products}  # bare Dict
    return [
        {
            "id": product_id,
            "name": index[product_id].name,
            "quantity": quantity,
        }
        for product_id, quantity in stock.items()
        if product_id in index
    ]
