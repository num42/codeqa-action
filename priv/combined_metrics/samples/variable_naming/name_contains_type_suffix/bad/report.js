// Report generation with type suffixes in variable names.
// BAD: variables include redundant type suffixes like String, List, Integer, Array, Hash.

function generate(params) {
  const userString = formatUserString(params.user);
  const dateString = params.date.toISOString().slice(0, 10);
  const titleString = buildTitleString(params.reportType);

  const rowArray = fetchRowArray(params.filters);
  const columnArray = params.columns;
  const tagArray = params.tags || [];

  const countInteger = rowArray.length;
  const pageCountInteger = Math.ceil(countInteger / params.pageSize);
  const totalInteger = sumTotalInteger(rowArray);

  const resultHash = buildResultHash(rowArray, columnArray);
  const summaryHash = computeSummaryHash(rowArray);

  return {
    title: titleString,
    generatedBy: userString,
    generatedOn: dateString,
    rows: rowArray,
    tags: tagArray,
    count: countInteger,
    pages: pageCountInteger,
    total: totalInteger,
    result: resultHash,
    summary: summaryHash,
  };
}

function exportReport(report, formatString) {
  const headerArray = extractHeaderArray(report);
  const dataArray = extractDataArray(report);

  if (formatString === 'csv') {
    const csvString = renderCsvString(headerArray, dataArray);
    return { ok: true, data: csvString };
  }

  if (formatString === 'json') {
    const jsonString = JSON.stringify(report);
    return { ok: true, data: jsonString };
  }

  return { ok: false, error: `Unsupported format: ${formatString}` };
}

function filterRows(rowArray, criteriaHash) {
  return rowArray.filter(row =>
    Object.entries(criteriaHash).every(([keyString, value]) => row[keyString] === value)
  );
}

function aggregate(rowArray, groupByArray) {
  const resultHash = {};

  for (const row of rowArray) {
    const keyString = groupByArray.map(field => row[field]).join('|');
    resultHash[keyString] = (resultHash[keyString] || 0) + 1;
  }

  return resultHash;
}

function paginate(rowArray, pageInteger, pageSizeInteger) {
  const startInteger = (pageInteger - 1) * pageSizeInteger;
  const endInteger = startInteger + pageSizeInteger;
  return rowArray.slice(startInteger, endInteger);
}

function formatUserString(user) { return `${user.firstName} ${user.lastName}`; }
function buildTitleString(type) { return `${type} Report`; }
function fetchRowArray() { return []; }
function sumTotalInteger(rows) { return rows.reduce((acc, r) => acc + (r.amount || 0), 0); }
function buildResultHash(rows, cols) { return { rows, columns: cols }; }
function computeSummaryHash(rows) { return { count: rows.length }; }
function extractHeaderArray(report) { return Object.keys(report); }
function extractDataArray(report) { return [Object.values(report)]; }
function renderCsvString(headers, data) { return headers.join(',') + '\n' + JSON.stringify(data); }

module.exports = { generate, exportReport, filterRows, aggregate, paginate };
