"""Data processing pipeline — GOOD: variables declared immediately before use."""

from datetime import datetime, timezone
import uuid


def process_order(order):
    min_price = 0.01
    max_items = 50

    validated = [
        item
        for item in order["items"]
        if item["quantity"] > 0
        and item["price"] >= min_price
        and len(order["items"]) <= max_items
    ]

    subtotal = sum(item["price"] * item["quantity"] for item in validated)

    discount_threshold = 100
    premium_discount = 0.15
    standard_discount = 0.05

    if subtotal > discount_threshold:
        discount = subtotal * premium_discount
    else:
        discount = subtotal * standard_discount

    discounted = subtotal - discount
    tax_rate = 0.08
    tax = discounted * tax_rate
    total = discounted + tax

    currency = "USD"
    return {"total": total, "currency": currency, "item_count": len(validated)}


def process_batch(orders):
    max_batch_size = 200

    if len(orders) > max_batch_size:
        return ("batch_error", "too_large")

    results = []
    for order in orders:
        outcome = process_order(order)
        if outcome["total"] > 0:
            results.append(("ok", outcome["total"]))
        else:
            results.append(("batch_error", order["id"]))

    successes = sum(1 for status, _ in results if status == "ok")
    batch_id = uuid.uuid4().hex
    started_at = datetime.now(timezone.utc)

    return {
        "batch_id": batch_id,
        "started_at": started_at,
        "total": len(orders),
        "successes": successes,
    }


def summarize(results):
    lines = [f"{status}: {val}" for status, val in results]
    body = "\n".join(lines)

    label = "Summary"
    separator = "-" * 40

    return f"{label}\n{separator}\n{body}"
