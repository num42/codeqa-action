"""Data processing pipeline — BAD: variables declared far from their use."""

from datetime import datetime, timezone
import uuid


def process_order(order):
    # All variables declared upfront, used much later
    tax_rate = 0.08
    discount_threshold = 100
    premium_discount = 0.15
    standard_discount = 0.05
    currency = "USD"
    max_items = 50
    min_price = 0.01

    items = order["items"]

    validated = [
        item
        for item in items
        if item["quantity"] > 0
        and item["price"] >= min_price
        and len(items) <= max_items
    ]

    subtotal = sum(item["price"] * item["quantity"] for item in validated)

    # discount_threshold, premium_discount, standard_discount declared ~15 lines ago
    if subtotal > discount_threshold:
        discount = subtotal * premium_discount
    else:
        discount = subtotal * standard_discount

    discounted = subtotal - discount

    # tax_rate declared ~22 lines ago
    tax = discounted * tax_rate

    total = discounted + tax

    # currency declared ~24 lines ago
    return {"total": total, "currency": currency, "item_count": len(validated)}


def process_batch(orders):
    # Variables declared at top, used at different depths
    batch_id = uuid.uuid4().hex
    started_at = datetime.now(timezone.utc)
    max_batch_size = 200
    error_tag = "batch_error"

    if len(orders) > max_batch_size:
        # error_tag used for the first time ~5 lines after declaration
        return (error_tag, "too_large")

    results = []
    for order in orders:
        outcome = process_order(order)
        if outcome["total"] > 0:
            results.append(("ok", outcome["total"]))
        else:
            # error_tag used again here, many lines from declaration
            results.append((error_tag, order["id"]))

    # started_at and batch_id used ~18 lines after declaration
    successes = sum(1 for status, _ in results if status == "ok")

    return {
        "batch_id": batch_id,
        "started_at": started_at,
        "total": len(orders),
        "successes": successes,
    }


def summarize(results):
    label = "Summary"
    separator = "-" * 40
    format_mode = "detailed"

    lines = [f"{status}: {val}" for status, val in results]
    body = "\n".join(lines)

    # label, separator, format_mode all declared ~7 lines ago
    if format_mode == "detailed":
        return f"{label}\n{separator}\n{body}"
    return f"{label}: {len(lines)} results"
