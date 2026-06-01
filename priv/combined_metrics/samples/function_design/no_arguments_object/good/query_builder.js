function buildSelectClause(table, ...columns) {
  if (columns.length === 0) {
    return `SELECT * FROM ${table}`;
  }
  const escaped = columns.map((c) => `"${c}"`).join(", ");
  return `SELECT ${escaped} FROM "${table}"`;
}

function buildWhereClause(...conditions) {
  if (conditions.length === 0) return "";
  return "WHERE " + conditions.join(" AND ");
}

function mergeQueryOptions(...optionSets) {
  return Object.assign({}, ...optionSets);
}

function buildOrderClause(...fields) {
  if (fields.length === 0) return "";
  const parts = fields.map(({ column, direction = "ASC" }) => `"${column}" ${direction}`);
  return "ORDER BY " + parts.join(", ");
}

function buildQuery(table, options = {}, ...extraConditions) {
  const { columns = [], conditions = [], orderBy = [], limit, offset } = options;

  const allConditions = [...conditions, ...extraConditions];

  const parts = [
    buildSelectClause(table, ...columns),
    buildWhereClause(...allConditions),
    buildOrderClause(...orderBy),
  ].filter(Boolean);

  if (limit != null) parts.push(`LIMIT ${Number(limit)}`);
  if (offset != null) parts.push(`OFFSET ${Number(offset)}`);

  return parts.join(" ");
}

function paginatedQuery(table, page, pageSize, ...baseConditions) {
  return buildQuery(table, {
    conditions: baseConditions,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });
}

export { buildQuery, buildSelectClause, buildWhereClause, buildOrderClause, paginatedQuery, mergeQueryOptions };
