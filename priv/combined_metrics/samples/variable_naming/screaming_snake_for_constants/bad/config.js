// Application config and HTTP client using incorrectly-cased module constants.
// BAD: module-level constants use camelCase or lowercase instead of SCREAMING_SNAKE_CASE.

const maxRetries = 3;
const defaultTimeout = 5000;
const apiBaseUrl = 'https://api.example.com/v1';
const pageSize = 25;
const retryDelay = 1000;
const maxPageSize = 100;
const connectTimeout = 2000;
const defaultHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

async function fetchData(path) {
  const url = apiBaseUrl + path;
  return requestWithRetry(url, maxRetries, defaultTimeout);
}

async function fetchPage(path, page) {
  const size = Math.min(page, maxPageSize);
  const url = `${apiBaseUrl}${path}?page=${page}&size=${size}`;
  return requestWithRetry(url, maxRetries, defaultTimeout);
}

async function paginateAll(path) {
  const allItems = [];
  let page = 1;

  while (true) {
    const result = await fetchPage(path, page);
    if (!result.ok) return result;

    allItems.push(...result.data.items);

    if (result.data.items.length < pageSize) break;
    page++;
  }

  return { ok: true, data: allItems };
}

async function postData(path, body) {
  const url = apiBaseUrl + path;
  return postWithRetry(url, body, maxRetries);
}

async function requestWithRetry(url, retriesLeft, timeout) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      headers: defaultHeaders,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (response.status >= 500 && retriesLeft > 0) {
      await sleep(retryDelay);
      return requestWithRetry(url, retriesLeft - 1, timeout);
    }

    if (!response.ok) return { ok: false, error: `HTTP ${response.status}` };

    const data = await response.json();
    return { ok: true, data };
  } catch (error) {
    clearTimeout(timeoutId);
    if (retriesLeft > 0) {
      await sleep(retryDelay);
      return requestWithRetry(url, retriesLeft - 1, timeout);
    }
    return { ok: false, error: error.message };
  }
}

async function postWithRetry(url, body, retriesLeft) {
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: defaultHeaders,
      body: JSON.stringify(body),
    });

    if ([200, 201].includes(response.status)) {
      return { ok: true, data: await response.json() };
    }

    if (retriesLeft > 0) {
      await sleep(retryDelay);
      return postWithRetry(url, body, retriesLeft - 1);
    }

    return { ok: false, error: `HTTP ${response.status}` };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

module.exports = { fetchData, fetchPage, paginateAll, postData };
