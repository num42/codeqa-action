// Query/struct builder — BAD: intermediate variables used exactly once.

class QueryBuilder {
  buildSearchQuery(filters) {
    const base = from("products");
    const withCategory = base.where({ category: filters.category });
    const withPrice = withCategory.whereLte("price", filters.maxPrice);
    const withStock = withPrice.whereGt("stock", 0);
    const ordered = withStock.orderBy("inserted_at");
    const limited = ordered.limit(filters.limit);
    return limited;
  }

  buildUserObject(attrs) {
    const name = attrs.name.trim();
    const email = attrs.email.toLowerCase();
    const role = attrs.role || "guest";
    const user = { name, email, role };
    return user;
  }

  formatReport(data) {
    const title = data.title.toUpperCase();
    const header = `=== ${title} ===`;
    const rows = data.rows.map((r) => this._formatRow(r));
    const body = rows.join("\n");
    const report = `${header}\n${body}`;
    return report;
  }

  buildNotification(event) {
    const subject = `Event: ${event.name}`;
    const recipient = event.user.email;
    const template = loadTemplate(event.type);
    const rendered = renderTemplate(template, event);
    const notification = { subject, to: recipient, body: rendered };
    return notification;
  }

  composeUrl(baseUrl, path, queryParams) {
    const encoded = new URLSearchParams(queryParams).toString();
    const fullPath = `${path}?${encoded}`;
    const url = `${baseUrl}${fullPath}`;
    return url;
  }

  _formatRow(row) {
    const label = row.label;
    const value = row.value;
    const line = `${label}: ${value}`;
    return line;
  }
}

function loadTemplate(t) {
  return `template_${t}`;
}

function renderTemplate(t, _e) {
  return t;
}

function from(_) {
  const q = {
    where: () => q,
    whereLte: () => q,
    whereGt: () => q,
    orderBy: () => q,
    limit: () => q,
  };
  return q;
}

module.exports = { QueryBuilder };
