"""Query/struct builder — GOOD: intermediate results are inlined."""

from urllib.parse import urlencode


class QueryBuilder:
    def build_search_query(self, filters):
        return (
            _from("products")
            .where(category=filters["category"])
            .where_lte("price", filters["max_price"])
            .where_gt("stock", 0)
            .order_by("inserted_at")
            .limit(filters["limit"])
        )

    def build_user_dict(self, attrs):
        return {
            "name": attrs["name"].strip(),
            "email": attrs["email"].lower(),
            "role": attrs.get("role") or "guest",
        }

    def format_report(self, data):
        header = f"=== {data['title'].upper()} ==="
        body = "\n".join(self._format_row(r) for r in data["rows"])
        return f"{header}\n{body}"

    def build_notification(self, event):
        return {
            "subject": f"Event: {event['name']}",
            "to": event["user"]["email"],
            "body": _render_template(_load_template(event["type"]), event),
        }

    def compose_url(self, base_url, path, query_params):
        return f"{base_url}{path}?{urlencode(query_params)}"

    def _format_row(self, row):
        return f"{row['label']}: {row['value']}"


def _load_template(t):
    return f"template_{t}"


def _render_template(t, _e):
    return t


class _from:
    def __init__(self, _t):
        pass

    def where(self, **_):
        return self

    def where_lte(self, *_):
        return self

    def where_gt(self, *_):
        return self

    def order_by(self, *_):
        return self

    def limit(self, *_):
        return self
