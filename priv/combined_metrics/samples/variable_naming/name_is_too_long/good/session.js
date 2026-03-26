// Session and auth management with concise, clear variable names.
// GOOD: currentUser, maxRetries, selectedProduct — short but descriptive.

async function startSession(email, password) {
  const user = await fetchUserByEmail(email);
  const isValid = await verifyPassword(password, user.passwordHash);

  if (!isValid) {
    throw new Error('Invalid credentials');
  }

  const token = generateSessionToken();
  const expiresAt = new Date(Date.now() + 86_400_000);

  return { token, expiresAt, userId: user.id };
}

async function validateSession(token) {
  const session = await lookupSession(token);
  const now = new Date();

  if (now > session.expiresAt) {
    throw new Error('Session expired');
  }

  return session;
}

async function refreshSession(oldToken) {
  const currentSession = await validateSession(oldToken);
  const newToken = generateSessionToken();
  const expiresAt = new Date(Date.now() + 86_400_000);

  return { token: newToken, expiresAt, userId: currentSession.userId };
}

async function listActiveSessions(userId) {
  const maxRetries = 3;
  const sessions = await fetchAllSessions(userId, maxRetries);
  const now = new Date();

  return sessions.filter(session => session.expiresAt > now);
}

async function currentUser(token) {
  const session = await validateSession(token);
  return fetchUserById(session.userId);
}

async function invalidateAllSessions(userId) {
  const activeSessions = await listActiveSessions(userId);
  await Promise.all(activeSessions.map(session => deleteSession(session.id)));
}

async function fetchUserByEmail(email) { return { id: 1, email, passwordHash: 'hash' }; }
async function verifyPassword(password) { return password.length > 0; }
function generateSessionToken() { return Math.random().toString(36).slice(2); }
async function lookupSession() { return { userId: 1, expiresAt: new Date(Date.now() + 3600_000) }; }
async function fetchAllSessions() { return []; }
async function fetchUserById(id) { return { id }; }
async function deleteSession() {}

module.exports = { startSession, validateSession, refreshSession, listActiveSessions, currentUser, invalidateAllSessions };
