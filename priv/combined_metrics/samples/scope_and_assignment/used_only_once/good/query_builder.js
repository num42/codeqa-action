// Query/struct builder — GOOD: intermediate results are inlined or chained.

class QueryBuilder {
  buildSearchQuery(filters) {
    return from("products")
      .where({ category: filters.category })
      .whereLte("price", filters.maxPrice)
      .whereGt("stock", 0)
      .orderBy("inserted_at")
      .limit(filters.limit);
  }

  buildUserObject(attrs) {
    return {
      name: attrs.name.trim(),
      email: attrs.email.toLowerCase(),
      role: attrs.role || "guest",
    };
  }

  formatReport(data) {
    const header = `=== ${data.title.toUpperCase()} ===`;
    const body = data.rows.map((r) => this._formatRow(r)).join("\n");
    return `${header}\n${body}`;
  }

  buildNotification(event) {
    return {
      subject: `Event: ${event.name}`,
      to: event.user.email,
      body: renderTemplate(loadTemplate(event.type), event),
    };
  }

  composeUrl(baseUrl, path, queryParams) {
    return `${baseUrl}${path}?${new URLSearchParams(queryParams).toString()}`;
  }

  _formatRow(row) {
    return `${row.label}: ${row.value}`;
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
