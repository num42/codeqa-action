"""Database manager providing connection pooling and query helpers."""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from typing import Any, Generator, Optional


DB_PATH = ":memory:"


@contextmanager
def get_connection(path: str = DB_PATH) -> Generator[sqlite3.Connection, None, None]:
    """Yield a database connection, committing on success and rolling back on error."""
    conn = sqlite3.connect(path)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def execute_query(
    sql: str,
    params: tuple = (),
    path: str = DB_PATH,
) -> list[dict[str, Any]]:
    """Run a SELECT query and return rows as dicts — connection closed automatically."""
    with get_connection(path) as conn:
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute(sql, params)
        return [dict(row) for row in cursor.fetchall()]


def execute_write(
    sql: str,
    params: tuple = (),
    path: str = DB_PATH,
) -> int:
    """Execute an INSERT/UPDATE/DELETE and return the number of affected rows."""
    with get_connection(path) as conn:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        return cursor.rowcount


def export_to_csv(
    sql: str,
    output_path: str,
    path: str = DB_PATH,
) -> int:
    """Export query results to a CSV file using context managers for both resources."""
    import csv
    rows = execute_query(sql, path=path)
    if not rows:
        return 0

    with open(output_path, "w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    return len(rows)
