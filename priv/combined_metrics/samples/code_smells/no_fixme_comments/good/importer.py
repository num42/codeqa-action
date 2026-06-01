"""Handles importing data from CSV and external sources."""

import re
from pathlib import Path


EMAIL_REGEX = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def import_csv(path):
    text = Path(path).read_text()
    if not text:
        return {"error": "empty_file"}

    rows = []
    for line in text.split("\n"):
        if not line.strip():
            continue
        parsed = parse_row(line)
        if parsed is not None:
            rows.append(parsed)
    return {"ok": rows}


def parse_row(line):
    parts = line.split(",")
    if len(parts) != 3:
        return None
    row_id, name, email = parts
    return {"id": row_id, "name": name, "email": email}


def import_users(rows):
    ok, errors = [], []
    for row in rows:
        result = insert_user(row)
        if result.get("ok"):
            ok.append(result)
        else:
            errors.append(result)
    return {"ok": len(ok), "errors": len(errors)}


def validate_row(row):
    normalized = row["email"].lower()
    if EMAIL_REGEX.match(normalized):
        return {"ok": {**row, "email": normalized}}
    return {"error": "invalid_email"}


def deduplicate(rows):
    seen = {}
    for row in rows:
        key = row["email"].lower()
        if key not in seen:
            seen[key] = {**row, "email": key}
    return list(seen.values())


def import_from_api(source_url):
    fetched = fetch_remote(source_url)
    if "error" in fetched:
        return fetched
    return parse_api_response(fetched["ok"])


def transform_row(row, field_map):
    return {dst: row.get(src) for src, dst in field_map.items()}


def write_results(results, output_path):
    output = Path(output_path)
    backup = output.with_suffix(output.suffix + ".bak")

    if output.exists():
        backup.write_bytes(output.read_bytes())

    content = "\n".join(format_result(r) for r in results)
    output.write_text(content)
    return {"ok": True}


def insert_user(row):
    return {"ok": row}


def fetch_remote(_url):
    return {"ok": []}


def parse_api_response(data):
    return {"ok": data}


def format_result(result):
    return repr(result)
