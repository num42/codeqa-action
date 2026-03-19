"""Data pipeline that streams and transforms records from a CSV source."""
from __future__ import annotations

import csv
import io
from typing import Generator, Iterable


def parse_rows(raw_csv: str) -> Generator[dict[str, str], None, None]:
    """Yield each CSV row as a dict without loading all rows into memory."""
    reader = csv.DictReader(io.StringIO(raw_csv))
    yield from reader


def normalise_record(record: dict[str, str]) -> dict[str, str | float]:
    """Return a cleaned copy of a single record."""
    return {
        "id": record.get("id", "").strip(),
        "name": record.get("name", "").strip().title(),
        "amount": float(record.get("amount", 0) or 0),
        "active": record.get("active", "false").lower() == "true",
    }


def filter_active(
    records: Iterable[dict],
) -> Generator[dict, None, None]:
    """Yield only records where active is True — generator, no full list built."""
    return (r for r in records if r.get("active"))


def total_amount(records: Iterable[dict]) -> float:
    """Sum amounts across records using a generator expression — no intermediate list."""
    return sum(r["amount"] for r in records)


def top_n_names(records: Iterable[dict], n: int) -> list[str]:
    """Return the n largest amounts' names.

    We only need to iterate once; a generator feeds sorted() directly.
    """
    sorted_records = sorted(
        (r for r in records if r.get("amount", 0) > 0),
        key=lambda r: r["amount"],
        reverse=True,
    )
    return [r["name"] for r in sorted_records[:n]]


def run_pipeline(raw_csv: str) -> dict:
    """Execute the full pipeline and return a summary."""
    rows = parse_rows(raw_csv)
    normalised = (normalise_record(r) for r in rows)  # generator, not list
    active = list(filter_active(normalised))           # materialise only once

    return {
        "total_records": len(active),
        "total_amount": total_amount(active),
        "top_3": top_n_names(active, 3),
    }
