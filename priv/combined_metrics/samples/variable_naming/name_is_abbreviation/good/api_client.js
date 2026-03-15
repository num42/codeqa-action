// HTTP API client using descriptive variable names.
// GOOD: variables like user, config, request, response, address, message are clear.

async function sendRequest(config, user) {
  const request = buildRequest(config, user);
  const url = config.baseUrl + request.path;

  try {
    const response = await fetch(url, {
      method: request.method,
      headers: request.headers,
      body: request.body,
    });

    const message = await response.json();
    return { ok: true, data: message };
  } catch (error) {
    return { ok: false, error: `Request failed: ${error.message}` };
  }
}

async function fetchProduct(config, productId) {
  const url = `${config.baseUrl}/products/${productId}`;
  const headers = authHeaders(config);

  try {
    const response = await fetch(url, { headers });

    if (!response.ok) {
      const message = `Unexpected status: ${response.status}`;
      return { ok: false, error: message };
    }

    const product = await response.json();
    return { ok: true, data: product };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function createOrder(config, user, quantity) {
  const url = `${config.baseUrl}/orders`;
  const request = {
    method: 'POST',
    headers: { ...authHeaders(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: user.id, quantity }),
  };

  try {
    const response = await fetch(url, request);
    const message = await response.json();

    if (!response.ok) return { ok: false, error: extractErrorMessage(message) };

    return { ok: true, data: message };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function paginate(config, params) {
  const queryString = new URLSearchParams(params).toString();
  const url = `${config.baseUrl}/items?${queryString}`;
  const headers = authHeaders(config);

  try {
    const response = await fetch(url, { headers });
    const data = await response.json();
    return { ok: true, data };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function uploadFile(config, user, buffer) {
  const url = `${config.baseUrl}/uploads`;
  const form = new FormData();
  form.append('file', buffer);
  form.append('userId', user.id);

  const response = await fetch(url, { method: 'POST', headers: authHeaders(config), body: form });
  const message = await response.json();
  return { ok: response.ok, data: message };
}

function buildRequest(config, user) {
  return { method: 'POST', path: '/requests', body: JSON.stringify({ userId: user.id }), headers: authHeaders(config) };
}

function authHeaders(config) {
  return { Authorization: `Bearer ${config.apiKey}` };
}

function extractErrorMessage(message) {
  return message.error || 'Unknown error';
}

module.exports = { sendRequest, fetchProduct, createOrder, paginate, uploadFile };
