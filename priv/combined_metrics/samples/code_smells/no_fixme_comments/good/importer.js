// Handles importing data from CSV and external sources.

const fs = require("fs");

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function importCsv(path) {
  const content = fs.readFileSync(path, "utf8");
  if (content === "") {
    return { error: "empty_file" };
  }

  const rows = content
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map(parseRow)
    .filter((row) => row !== null);

  return { ok: rows };
}

function parseRow(line) {
  const parts = line.split(",");
  if (parts.length !== 3) {
    return null;
  }
  const [id, name, email] = parts;
  return { id, name, email };
}

function importUsers(rows) {
  const results = rows.map(insertUser);
  const ok = results.filter((r) => r.ok).length;
  const errors = results.length - ok;
  return { ok, errors };
}

function validateRow(row) {
  const normalized = row.email.toLowerCase();
  if (EMAIL_REGEX.test(normalized)) {
    return { ok: { ...row, email: normalized } };
  }
  return { error: "invalid_email" };
}

function deduplicate(rows) {
  const seen = new Map();
  for (const row of rows) {
    const key = row.email.toLowerCase();
    if (!seen.has(key)) {
      seen.set(key, { ...row, email: key });
    }
  }
  return Array.from(seen.values());
}

function importFromApi(sourceUrl) {
  const fetched = fetchRemote(sourceUrl);
  if (fetched.error) {
    return fetched;
  }
  return parseApiResponse(fetched.ok);
}

function transformRow(row, fieldMap) {
  const result = {};
  for (const [src, dst] of Object.entries(fieldMap)) {
    result[dst] = row[src];
  }
  return result;
}

function writeResults(results, outputPath) {
  const backupPath = `${outputPath}.bak`;
  if (fs.existsSync(outputPath)) {
    fs.copyFileSync(outputPath, backupPath);
  }
  const content = results.map(formatResult).join("\n");
  fs.writeFileSync(outputPath, content);
  return { ok: true };
}

function insertUser(row) {
  return { ok: row };
}

function fetchRemote(_url) {
  return { ok: [] };
}

function parseApiResponse(data) {
  return { ok: data };
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
