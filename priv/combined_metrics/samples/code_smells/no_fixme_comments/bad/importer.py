"""Handles importing data from CSV and external sources."""

from pathlib import Path


# FIXME: this crashes on empty files, need to handle that
def import_csv(path):
    text = Path(path).read_text()
    rows = []
    for line in text.split("\n"):
        parsed = parse_row(line)
        if parsed is not None:
            rows.append(parsed)
    return rows


# TODO: FIXME - validate headers before parsing rows
def parse_row(line):
    parts = line.split(",")
    if len(parts) == 3:
        row_id, name, email = parts
        return {"id": row_id, "name": name, "email": email}
    # XXX: silently drops malformed rows, should log or collect errors
    return None


def import_users(rows):
    # FIXME: this does N+1 inserts, wrap in a transaction
    return [insert_user(row) for row in rows]


def validate_row(row):
    # XXX: email regex is wrong, doesn't handle subdomains
    if "@" in row["email"]:
        return {"ok": row}
    return {"error": "invalid_email"}


def deduplicate(rows):
    # FIXME: uses email as dedup key but doesn't normalize case first
    seen = {}
    for row in rows:
        if row["email"] not in seen:
            seen[row["email"]] = row
    return list(seen.values())


def import_from_api(source_url):
    # TODO: FIXME - add retry logic and timeout handling
    fetched = fetch_remote(source_url)
    if fetched is not None:
        return parse_api_response(fetched)
    # XXX: swallows all errors, need proper error propagation
    return []


def transform_row(row, field_map):
    # FIXME: doesn't handle nested fields or type coercion
    return {dst: row.get(src) for src, dst in field_map.items()}


def write_results(results, output_path):
    # XXX: overwrites file without backup, could lose data
    content = "\n".join(format_result(r) for r in results)
    Path(output_path).write_text(content)


def insert_user(row):
    return {"ok": row}


def fetch_remote(_url):
    return []


def parse_api_response(data):
    return data


def format_result(result):
    return repr(result)
