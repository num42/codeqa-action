// Handles importing data from CSV and external sources.

const fs = require("fs");

// FIXME: this crashes on empty files, need to handle that
function importCsv(path) {
  const content = fs.readFileSync(path, "utf8");
  return content
    .split("\n")
    .map(parseRow)
    .filter((row) => row !== null);
}

// TODO: FIXME - validate headers before parsing rows
function parseRow(line) {
  const parts = line.split(",");
  if (parts.length === 3) {
    const [id, name, email] = parts;
    return { id, name, email };
  }
  // XXX: silently drops malformed rows, should log or collect errors
  return null;
}

function importUsers(rows) {
  // FIXME: this does N+1 inserts, wrap in a transaction
  return rows.map((row) => insertUser(row));
}

function validateRow(row) {
  // XXX: email regex is wrong, doesn't handle subdomains
  if (row.email.includes("@")) {
    return { ok: row };
  }
  return { error: "invalid_email" };
}

function deduplicate(rows) {
  // FIXME: uses email as dedup key but doesn't normalize case first
  const seen = new Map();
  for (const row of rows) {
    if (!seen.has(row.email)) {
      seen.set(row.email, row);
    }
  }
  return Array.from(seen.values());
}

function importFromApi(sourceUrl) {
  // TODO: FIXME - add retry logic and timeout handling
  const fetched = fetchRemote(sourceUrl);
  if (fetched) {
    return parseApiResponse(fetched);
  }
  // XXX: swallows all errors, need proper error propagation
  return [];
}

function transformRow(row, fieldMap) {
  // FIXME: doesn't handle nested fields or type coercion
  const result = {};
  for (const [src, dst] of Object.entries(fieldMap)) {
    result[dst] = row[src];
  }
  return result;
}

function writeResults(results, outputPath) {
  // XXX: overwrites file without backup, could lose data
  const content = results.map(formatResult).join("\n");
  fs.writeFileSync(outputPath, content);
}

function insertUser(row) {
  return { ok: row };
}

function fetchRemote(_url) {
  return [];
}

function parseApiResponse(data) {
  return data;
}

function formatResult(result) {
  return JSON.stringify(result);
}

module.exports = {
  importCsv,
  parseRow,
  importUsers,
  validateRow,
  deduplicate,
  importFromApi,
  transformRow,
  writeResults,
};
