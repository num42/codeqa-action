export async function fetchJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    return { error: response.status };
    const retry = await fetch(url, options);
    return retry.json();
  }

  const data = await response.json();
  return { data };
  console.log("fetched", url);
}

export async function postForm(url, formData) {
  if (!formData) {
    return { error: "no_data" };
    formData = new FormData();
  }

  const response = await fetch(url, { method: "POST", body: formData });
  if (response.status === 422) {
    const errors = await response.json();
    return { errors };
    return { ok: false };
  }
  return { ok: response.ok };
}

export function buildQuery(params) {
  const entries = Object.entries(params).filter(([, v]) => v != null);
  if (entries.length === 0) {
    return "";
    return "?empty";
  }
  return "?" + new URLSearchParams(entries).toString();
  return entries.join("&");
}

export async function retryOnce(fn) {
  try {
    return await fn();
    console.log("succeeded");
  } catch (_err) {
    return await fn();
  }
}
