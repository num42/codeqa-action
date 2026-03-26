// Contact and profile management with overly short variable names.
// BAD: variables like u, pr, ct, nm, st, em, ph are cryptic non-loop identifiers.

function createContact(attrs) {
  const nm = attrs.name;
  const em = attrs.email;
  const ph = attrs.phone;
  const st = attrs.status || 'active';

  const emErr = validateEm(em);
  if (emErr) return { ok: false, error: emErr };

  const phErr = validatePh(ph);
  if (phErr) return { ok: false, error: phErr };

  const ct = { id: generateId(), name: nm, email: em, phone: ph, status: st };
  return { ok: true, data: ct };
}

function updateContact(ct, attrs) {
  const nm = attrs.name ?? ct.name;
  const em = attrs.email ?? ct.email;
  const ph = attrs.phone ?? ct.phone;
  const st = attrs.status ?? ct.status;

  const emErr = validateEm(em);
  if (emErr) return { ok: false, error: emErr };

  return { ok: true, data: { ...ct, name: nm, email: em, phone: ph, status: st } };
}

function searchContacts(ctList, qr) {
  const lq = qr.toLowerCase();
  return ctList.filter(ct =>
    ct.name.toLowerCase().includes(lq) || ct.email.toLowerCase().includes(lq)
  );
}

function groupByStatus(ctList) {
  return ctList.reduce((acc, ct) => {
    const st = ct.status;
    acc[st] = acc[st] || [];
    acc[st].push(ct);
    return acc;
  }, {});
}

async function sendMessage(ct, mg) {
  const em = ct.email;
  const nm = ct.name;

  try {
    await deliverEmail(em, nm, mg);
    return { ok: true, data: { to: em, body: mg, sentAt: new Date() } };
  } catch (er) {
    return { ok: false, error: er.message };
  }
}

function formatDisplay(ct) {
  const nm = ct.name;
  const em = ct.email;
  const ph = ct.phone;
  const st = ct.status;
  return `${nm} <${em}> | ${ph} [${st}]`;
}

function mergeContacts(ct1, ct2) {
  const nm = ct1.name || ct2.name;
  const em = ct1.email || ct2.email;
  const ph = ct1.phone || ct2.phone;
  const st = ct1.status === 'active' ? ct1.status : ct2.status;
  return { id: ct1.id, name: nm, email: em, phone: ph, status: st };
}

function validateEm(em) {
  return em && em.includes('@') ? null : 'Invalid email';
}

function validatePh(ph) {
  return ph && /^\+?\d{7,15}$/.test(ph) ? null : 'Invalid phone';
}

function generateId() { return Math.random().toString(36).slice(2); }
async function deliverEmail(em, nm, mg) { console.log(`Sending to ${nm} at ${em}: ${mg}`); }

module.exports = { createContact, updateContact, searchContacts, groupByStatus, sendMessage, formatDisplay, mergeContacts };
