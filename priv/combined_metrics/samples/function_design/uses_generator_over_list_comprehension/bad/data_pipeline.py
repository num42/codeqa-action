"""Data pipeline that streams and transforms records from a CSV source."""
from __future__ import annotations

import csv
import io


def parse_rows(raw_csv: str) -> list[dict[str, str]]:
    """Return ALL CSV rows as a list — entire dataset loaded into memory."""
    reader = csv.DictReader(io.StringIO(raw_csv))
    return [row for row in reader]  # unnecessary full materialisation


def normalise_record(record: dict[str, str]) -> dict:
    return {
        "id": record.get("id", "").strip(),
        "name": record.get("name", "").strip().title(),
        "amount": float(record.get("amount", 0) or 0),
        "active": record.get("active", "false").lower() == "true",
    }


def filter_active(records: list[dict]) -> list[dict]:
    """Build a full list of active records even if we only need to iterate once."""
    return [r for r in records if r.get("active")]  # list when a generator suffices


def total_amount(records: list[dict]) -> float:
    """Convert to list before summing — wastes memory for large record sets."""
    amounts = [r["amount"] for r in records]  # builds full list just to sum it
    return sum(amounts)


def top_n_names(records: list[dict], n: int) -> list[str]:
    """Creates multiple intermediate lists unnecessarily."""
    filtered = [r for r in records if r.get("amount", 0) > 0]  # list 1
    sorted_records = sorted(filtered, key=lambda r: r["amount"], reverse=True)
    names = [r["name"] for r in sorted_records]  # list 2 — all names, not just n
    return names[:n]


def run_pipeline(raw_csv: str) -> dict:
    """Executes the full pipeline — every step materialises a new list."""
    rows = parse_rows(raw_csv)
    normalised = [normalise_record(r) for r in rows]  # list
    active = filter_active(normalised)                  # another list

    return {
        "total_records": len(active),
        "total_amount": total_amount(active),
        "top_3": top_n_names(active, 3),
    }
