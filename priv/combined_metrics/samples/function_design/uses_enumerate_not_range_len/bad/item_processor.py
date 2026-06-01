"""Item processor that validates, transforms, and ranks catalogue entries."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class CatalogueItem:
    sku: str
    name: str
    price: float
    stock: int


def validate_items(items: list) -> list:
    """Return a list of (index, error_message) for any invalid items."""
    errors = []
    for i in range(len(items)):          # range(len(...)) instead of enumerate
        item = items[i]
        if item.price < 0:
            errors.append((i, f"Item {item.sku}: negative price {item.price}"))
        if item.stock < 0:
            errors.append((i, f"Item {item.sku}: negative stock {item.stock}"))
        if not item.name.strip():
            errors.append((i, f"Item {item.sku}: empty name"))
    return errors


def apply_discount(items: list, percent: float) -> list:
    """Return new items with a discount applied."""
    factor = 1.0 - percent / 100.0
    result = []
    for i in range(len(items)):          # range(len(...)) instead of a direct loop
        item = items[i]
        result.append(
            CatalogueItem(
                sku=item.sku,
                name=item.name,
                price=round(item.price * factor, 2),
                stock=item.stock,
            )
        )
    return result


def find_duplicates(items: list) -> list:
    """Return index pairs (i, j) where items share the same SKU."""
    duplicates = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):   # nested range(len(...))
            if items[i].sku == items[j].sku:
                duplicates.append((i, j))
    return duplicates


def format_listing(items: list) -> list:
    """Produce numbered display strings for each item."""
    lines = []
    for i in range(len(items)):          # range(len(...)) again
        item = items[i]
        lines.append(
            f"{i + 1}. [{item.sku}] {item.name} — ${item.price:.2f} ({item.stock} in stock)"
        )
    return lines
