// Application config and HTTP client using correctly-cased module constants.
// GOOD: module-level constants use SCREAMING_SNAKE_CASE to distinguish them from variables.

const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT = 5000;
const API_BASE_URL = 'https://api.example.com/v1';
const PAGE_SIZE = 25;
const RETRY_DELAY = 1000;
const MAX_PAGE_SIZE = 100;
const CONNECT_TIMEOUT = 2000;
const DEFAULT_HEADERS = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

async function fetchData(path) {
  const url = API_BASE_URL + path;
  return requestWithRetry(url, MAX_RETRIES, DEFAULT_TIMEOUT);
}

async function fetchPage(path, page) {
  const size = Math.min(page, MAX_PAGE_SIZE);
  const url = `${API_BASE_URL}${path}?page=${page}&size=${size}`;
  return requestWithRetry(url, MAX_RETRIES, DEFAULT_TIMEOUT);
}

async function paginateAll(path) {
  const allItems = [];
  let page = 1;

  while (true) {
    const result = await fetchPage(path, page);
    if (!result.ok) return result;

    allItems.push(...result.data.items);

    if (result.data.items.length < PAGE_SIZE) break;
    page++;
  }

  return { ok: true, data: allItems };
}

async function postData(path, body) {
  const url = API_BASE_URL + path;
  return postWithRetry(url, body, MAX_RETRIES);
}

async function requestWithRetry(url, retriesLeft, timeout) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      headers: DEFAULT_HEADERS,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (response.status >= 500 && retriesLeft > 0) {
      await sleep(RETRY_DELAY);
      return requestWithRetry(url, retriesLeft - 1, timeout);
    }

    if (!response.ok) return { ok: false, error: `HTTP ${response.status}` };

    const data = await response.json();
    return { ok: true, data };
  } catch (error) {
    clearTimeout(timeoutId);
    if (retriesLeft > 0) {
      await sleep(RETRY_DELAY);
      return requestWithRetry(url, retriesLeft - 1, timeout);
    }
    return { ok: false, error: error.message };
  }
}

async function postWithRetry(url, body, retriesLeft) {
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: DEFAULT_HEADERS,
      body: JSON.stringify(body),
    });

    if ([200, 201].includes(response.status)) {
      return { ok: true, data: await response.json() };
    }

    if (retriesLeft > 0) {
      await sleep(RETRY_DELAY);
      return postWithRetry(url, body, retriesLeft - 1);
    }

    return { ok: false, error: `HTTP ${response.status}` };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

module.exports = { fetchData, fetchPage, paginateAll, postData };
