// Contact and profile management with clear, readable variable names.
// GOOD: user, price, count, name, status, email, phone — obvious at a glance.

function createContact(attrs) {
  const name = attrs.name;
  const email = attrs.email;
  const phone = attrs.phone;
  const status = attrs.status || 'active';

  const emailError = validateEmail(email);
  if (emailError) return { ok: false, error: emailError };

  const phoneError = validatePhone(phone);
  if (phoneError) return { ok: false, error: phoneError };

  const contact = { id: generateId(), name, email, phone, status };
  return { ok: true, data: contact };
}

function updateContact(contact, attrs) {
  const name = attrs.name ?? contact.name;
  const email = attrs.email ?? contact.email;
  const phone = attrs.phone ?? contact.phone;
  const status = attrs.status ?? contact.status;

  const emailError = validateEmail(email);
  if (emailError) return { ok: false, error: emailError };

  return { ok: true, data: { ...contact, name, email, phone, status } };
}

function searchContacts(contacts, query) {
  const lowerQuery = query.toLowerCase();
  return contacts.filter(contact =>
    contact.name.toLowerCase().includes(lowerQuery) ||
    contact.email.toLowerCase().includes(lowerQuery)
  );
}

function groupByStatus(contacts) {
  return contacts.reduce((acc, contact) => {
    const status = contact.status;
    acc[status] = acc[status] || [];
    acc[status].push(contact);
    return acc;
  }, {});
}

async function sendMessage(contact, message) {
  const email = contact.email;
  const name = contact.name;

  try {
    await deliverEmail(email, name, message);
    return { ok: true, data: { to: email, body: message, sentAt: new Date() } };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

function formatDisplay(contact) {
  const name = contact.name;
  const email = contact.email;
  const phone = contact.phone;
  const status = contact.status;
  return `${name} <${email}> | ${phone} [${status}]`;
}

function mergeContacts(primary, secondary) {
  const name = primary.name || secondary.name;
  const email = primary.email || secondary.email;
  const phone = primary.phone || secondary.phone;
  const status = primary.status === 'active' ? primary.status : secondary.status;
  return { id: primary.id, name, email, phone, status };
}

function validateEmail(email) {
  return email && email.includes('@') ? null : 'Invalid email';
}

function validatePhone(phone) {
  return phone && /^\+?\d{7,15}$/.test(phone) ? null : 'Invalid phone';
}

function generateId() { return Math.random().toString(36).slice(2); }
async function deliverEmail(email, name, message) { console.log(`Sending to ${name} at ${email}: ${message}`); }

module.exports = { createContact, updateContact, searchContacts, groupByStatus, sendMessage, formatDisplay, mergeContacts };
