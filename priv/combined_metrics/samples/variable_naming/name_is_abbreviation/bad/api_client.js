// HTTP API client using abbreviated variable names.
// BAD: variables like usr, cfg, req, res, addr, msg obscure intent.

async function sendRequest(cfg, usr) {
  const req = buildReq(cfg, usr);
  const addr = cfg.baseUrl + req.path;

  try {
    const res = await fetch(addr, {
      method: req.method,
      headers: req.headers,
      body: req.body,
    });

    const msg = await res.json();
    return { ok: true, data: msg };
  } catch (err) {
    return { ok: false, error: `Request failed: ${err.message}` };
  }
}

async function fetchProduct(cfg, prdId) {
  const addr = `${cfg.baseUrl}/products/${prdId}`;
  const req = { headers: authHeaders(cfg) };

  try {
    const res = await fetch(addr, req);

    if (!res.ok) {
      const msg = `Unexpected status: ${res.status}`;
      return { ok: false, error: msg };
    }

    const prd = await res.json();
    return { ok: true, data: prd };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

async function createOrder(cfg, usr, qty) {
  const addr = `${cfg.baseUrl}/orders`;
  const req = {
    method: 'POST',
    headers: { ...authHeaders(cfg), 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: usr.id, quantity: qty }),
  };

  try {
    const res = await fetch(addr, req);
    const msg = await res.json();

    if (!res.ok) return { ok: false, error: extractErrMsg(msg) };

    return { ok: true, data: msg };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

async function paginate(cfg, params) {
  const qry = new URLSearchParams(params).toString();
  const addr = `${cfg.baseUrl}/items?${qry}`;
  const req = { headers: authHeaders(cfg) };

  try {
    const res = await fetch(addr, req);
    const msg = await res.json();
    return { ok: true, data: msg };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

async function uploadFile(cfg, usr, buf) {
  const addr = `${cfg.baseUrl}/uploads`;
  const frm = new FormData();
  frm.append('file', buf);
  frm.append('userId', usr.id);

  const res = await fetch(addr, { method: 'POST', headers: authHeaders(cfg), body: frm });
  const msg = await res.json();
  return { ok: res.ok, data: msg };
}

function buildReq(cfg, usr) {
  return { method: 'POST', path: '/requests', body: JSON.stringify({ userId: usr.id }), headers: authHeaders(cfg) };
}

function authHeaders(cfg) {
  return { Authorization: `Bearer ${cfg.apiKey}` };
}

function extractErrMsg(msg) {
  return msg.error || 'Unknown error';
}

module.exports = { sendRequest, fetchProduct, createOrder, paginate, uploadFile };
