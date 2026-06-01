"""Query/struct builder — BAD: intermediate variables used exactly once."""

from urllib.parse import urlencode


class QueryBuilder:
    def build_search_query(self, filters):
        base = _from("products")
        with_category = base.where(category=filters["category"])
        with_price = with_category.where_lte("price", filters["max_price"])
        with_stock = with_price.where_gt("stock", 0)
        ordered = with_stock.order_by("inserted_at")
        limited = ordered.limit(filters["limit"])
        return limited

    def build_user_dict(self, attrs):
        name = attrs["name"].strip()
        email = attrs["email"].lower()
        role = attrs.get("role") or "guest"
        user = {"name": name, "email": email, "role": role}
        return user

    def format_report(self, data):
        title = data["title"].upper()
        header = f"=== {title} ==="
        rows = [self._format_row(r) for r in data["rows"]]
        body = "\n".join(rows)
        report = f"{header}\n{body}"
        return report

    def build_notification(self, event):
        subject = f"Event: {event['name']}"
        recipient = event["user"]["email"]
        template = _load_template(event["type"])
        rendered = _render_template(template, event)
        notification = {"subject": subject, "to": recipient, "body": rendered}
        return notification

    def compose_url(self, base_url, path, query_params):
        encoded = urlencode(query_params)
        full_path = f"{path}?{encoded}"
        url = f"{base_url}{full_path}"
        return url

    def _format_row(self, row):
        label = row["label"]
        value = row["value"]
        line = f"{label}: {value}"
        return line


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
