function buildSelectClause() {
  const table = arguments[0];
  if (arguments.length <= 1) {
    return `SELECT * FROM ${table}`;
  }
  const columns = [];
  for (let i = 1; i < arguments.length; i++) {
    columns.push(`"${arguments[i]}"`);
  }
  return `SELECT ${columns.join(", ")} FROM "${table}"`;
}

function buildWhereClause() {
  if (arguments.length === 0) return "";
  const conditions = [];
  for (let i = 0; i < arguments.length; i++) {
    conditions.push(arguments[i]);
  }
  return "WHERE " + conditions.join(" AND ");
}

function mergeQueryOptions() {
  const result = {};
  for (let i = 0; i < arguments.length; i++) {
    Object.assign(result, arguments[i]);
  }
  return result;
}

function buildOrderClause() {
  if (arguments.length === 0) return "";
  const parts = [];
  for (let i = 0; i < arguments.length; i++) {
    const field = arguments[i];
    parts.push(`"${field.column}" ${field.direction || "ASC"}`);
  }
  return "ORDER BY " + parts.join(", ");
}

function buildQuery(table, options) {
  const columns = options.columns || [];
  const conditions = options.conditions || [];
  const orderBy = options.orderBy || [];

  const selectPart = buildSelectClause.apply(null, [table].concat(columns));
  const wherePart = buildWhereClause.apply(null, conditions);
  const orderPart = buildOrderClause.apply(null, orderBy);

  const parts = [selectPart, wherePart, orderPart].filter(Boolean);

  if (options.limit != null) parts.push(`LIMIT ${Number(options.limit)}`);
  if (options.offset != null) parts.push(`OFFSET ${Number(options.offset)}`);

  return parts.join(" ");
}

export { buildQuery, buildSelectClause, buildWhereClause, buildOrderClause, mergeQueryOptions };
