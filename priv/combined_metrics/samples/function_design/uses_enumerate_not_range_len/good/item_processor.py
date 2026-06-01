"""Item processor that validates, transforms, and ranks catalogue entries."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class CatalogueItem:
    sku: str
    name: str
    price: float
    stock: int


def validate_items(items: list[CatalogueItem]) -> list[tuple[int, str]]:
    """Return a list of (index, error_message) for any invalid items."""
    errors: list[tuple[int, str]] = []
    for index, item in enumerate(items):
        if item.price < 0:
            errors.append((index, f"Item {item.sku}: negative price {item.price}"))
        if item.stock < 0:
            errors.append((index, f"Item {item.sku}: negative stock {item.stock}"))
        if not item.name.strip():
            errors.append((index, f"Item {item.sku}: empty name"))
    return errors


def apply_discount(items: list[CatalogueItem], percent: float) -> list[CatalogueItem]:
    """Return new items with a discount applied, preserving original order."""
    factor = 1.0 - percent / 100.0
    return [
        CatalogueItem(
            sku=item.sku,
            name=item.name,
            price=round(item.price * factor, 2),
            stock=item.stock,
        )
        for item in items
    ]


def find_duplicates(items: list[CatalogueItem]) -> list[tuple[int, int]]:
    """Return index pairs (i, j) where items share the same SKU."""
    duplicates: list[tuple[int, int]] = []
    for i, item_a in enumerate(items):
        for j, item_b in enumerate(items[i + 1 :], start=i + 1):
            if item_a.sku == item_b.sku:
                duplicates.append((i, j))
    return duplicates


def rank_by_value(items: list[CatalogueItem]) -> list[tuple[int, CatalogueItem]]:
    """Return items sorted by total value (price * stock), with their original index."""
    indexed = list(enumerate(items))
    return sorted(indexed, key=lambda pair: pair[1].price * pair[1].stock, reverse=True)


def format_listing(items: list[CatalogueItem]) -> list[str]:
    """Produce numbered display strings for each item."""
    return [
        f"{position + 1}. [{item.sku}] {item.name} — ${item.price:.2f} ({item.stock} in stock)"
        for position, item in enumerate(items)
    ]
