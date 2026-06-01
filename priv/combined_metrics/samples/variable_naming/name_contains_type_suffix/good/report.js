// Report generation without type suffixes in variable names.
// GOOD: variable names express what the data is, not what type it has.

function generate(params) {
  const user = formatUser(params.user);
  const date = params.date.toISOString().slice(0, 10);
  const title = buildTitle(params.reportType);

  const rows = fetchRows(params.filters);
  const columns = params.columns;
  const tags = params.tags || [];

  const count = rows.length;
  const pageCount = Math.ceil(count / params.pageSize);
  const total = sumTotal(rows);

  const result = buildResult(rows, columns);
  const summary = computeSummary(rows);

  return {
    title,
    generatedBy: user,
    generatedOn: date,
    rows,
    tags,
    count,
    pages: pageCount,
    total,
    result,
    summary,
  };
}

function exportReport(report, format) {
  const headers = extractHeaders(report);
  const data = extractData(report);

  if (format === 'csv') {
    const csv = renderCsv(headers, data);
    return { ok: true, data: csv };
  }

  if (format === 'json') {
    const json = JSON.stringify(report);
    return { ok: true, data: json };
  }

  return { ok: false, error: `Unsupported format: ${format}` };
}

function filterRows(rows, criteria) {
  return rows.filter(row =>
    Object.entries(criteria).every(([key, value]) => row[key] === value)
  );
}

function aggregate(rows, groupBy) {
  const result = {};

  for (const row of rows) {
    const key = groupBy.map(field => row[field]).join('|');
    result[key] = (result[key] || 0) + 1;
  }

  return result;
}

function paginate(rows, page, pageSize) {
  const start = (page - 1) * pageSize;
  const end = start + pageSize;
  return rows.slice(start, end);
}

function formatUser(user) { return `${user.firstName} ${user.lastName}`; }
function buildTitle(type) { return `${type} Report`; }
function fetchRows() { return []; }
function sumTotal(rows) { return rows.reduce((acc, r) => acc + (r.amount || 0), 0); }
function buildResult(rows, cols) { return { rows, columns: cols }; }
function computeSummary(rows) { return { count: rows.length }; }
function extractHeaders(report) { return Object.keys(report); }
function extractData(report) { return [Object.values(report)]; }
function renderCsv(headers, data) { return headers.join(',') + '\n' + JSON.stringify(data); }

module.exports = { generate, exportReport, filterRows, aggregate, paginate };
