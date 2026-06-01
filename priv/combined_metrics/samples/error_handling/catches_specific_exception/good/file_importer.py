"""File importer that reads, parses, and ingests CSV data files."""
from __future__ import annotations

import csv
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
    """Read a file and return its contents, raising descriptive errors."""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Import file not found: {path}")
    except PermissionError:
        raise PermissionError(f"No read permission for file: {path}")
    except UnicodeDecodeError as exc:
        raise ValueError(f"File {path} is not valid UTF-8") from exc


def parse_csv(content: str) -> list[dict[str, str]]:
    """Parse CSV text into a list of row dicts."""
    import io
    try:
        reader = csv.DictReader(io.StringIO(content))
        return list(reader)
    except csv.Error as exc:
        raise ValueError(f"Malformed CSV content: {exc}") from exc


def convert_row(row: dict[str, str]) -> dict:
    """Convert raw string values to typed fields."""
    try:
        return {
            "id": int(row["id"]),
            "name": row["name"].strip(),
            "amount": float(row["amount"]),
        }
    except KeyError as exc:
        raise ValueError(f"Missing required column: {exc}") from exc
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Type conversion failed for row {row}: {exc}") from exc


def import_file(path: str) -> ImportResult:
    """Import a CSV file, skipping rows that fail conversion."""
    filename = os.path.basename(path)
    content = read_file(path)
    rows = parse_csv(content)

    imported, skipped = 0, 0
    for row in rows:
        try:
            convert_row(row)
            imported += 1
        except ValueError:
            skipped += 1

    return ImportResult(filename=filename, rows_imported=imported, rows_skipped=skipped)
