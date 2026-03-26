"""File importer that reads, parses, and ingests CSV data files."""
from __future__ import annotations

import csv
import io
import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class ImportResult:
    filename: str
    rows_imported: int
    rows_skipped: int
    error: Optional[str] = None


def read_file(path: str) -> str:
    """Read a file — catches all exceptions, masking programming errors."""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except Exception:          # too broad: hides PermissionError, MemoryError, etc.
        return ""


def parse_csv(content: str) -> list:
    """Parse CSV text — broad catch swallows malformed-data signals."""
    try:
        reader = csv.DictReader(io.StringIO(content))
        return list(reader)
    except Exception as e:     # catches everything including KeyboardInterrupt chain
        print(f"parse error: {e}")
        return []


def convert_row(row: dict) -> dict:
    """Convert raw string values — broad except prevents surfacing schema issues."""
    try:
        return {
            "id": int(row["id"]),
            "name": row["name"].strip(),
            "amount": float(row["amount"]),
        }
    except Exception:          # hides KeyError (missing column) vs ValueError (bad data)
        return {}


def import_file(path: str) -> ImportResult:
    """Import a CSV file — catches everything so failures are silently swallowed."""
    filename = os.path.basename(path)
    try:
        content = read_file(path)
        rows = parse_csv(content)
        imported = 0
        skipped = 0
        for row in rows:
            result = convert_row(row)
            if result:
                imported += 1
            else:
                skipped += 1
        return ImportResult(filename=filename, rows_imported=imported, rows_skipped=skipped)
    except Exception as e:     # outermost catch hides all failures
        return ImportResult(filename=filename, rows_imported=0, rows_skipped=0, error=str(e))
