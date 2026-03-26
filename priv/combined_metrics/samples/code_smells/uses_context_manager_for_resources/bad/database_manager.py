"""Database manager providing connection pooling and query helpers."""
from __future__ import annotations

import sqlite3
from typing import Any, Optional


DB_PATH = ":memory:"


def get_connection(path: str = DB_PATH) -> sqlite3.Connection:
    """Return a raw connection — caller is responsible for closing it."""
    return sqlite3.connect(path)


def execute_query(
    sql: str,
    params: tuple = (),
    path: str = DB_PATH,
) -> list[dict[str, Any]]:
    """Run a SELECT query — connection left open if an exception is raised."""
    conn = get_connection(path)               # no context manager
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute(sql, params)               # if this raises, conn is never closed
    rows = [dict(row) for row in cursor.fetchall()]
    conn.close()                              # only reached on success
    return rows


def execute_write(
    sql: str,
    params: tuple = (),
    path: str = DB_PATH,
) -> int:
    """Execute a write — connection leaked on error; no rollback on failure."""
    conn = get_connection(path)
    cursor = conn.cursor()
    cursor.execute(sql, params)               # exception here leaks conn
    conn.commit()
    conn.close()
    return cursor.rowcount


def export_to_csv(
    sql: str,
    output_path: str,
    path: str = DB_PATH,
) -> int:
    """Export results — both file and connection are manually managed."""
    import csv
    rows = execute_query(sql, path=path)
    if not rows:
        return 0

    csv_file = open(output_path, "w", newline="", encoding="utf-8")  # no 'with'
    writer = csv.DictWriter(csv_file, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
    csv_file.close()    # only reached if writerows() doesn't raise

    return len(rows)
