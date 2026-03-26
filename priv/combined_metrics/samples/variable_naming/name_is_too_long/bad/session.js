// Session and auth management with excessively long variable names.
// BAD: variables like theCurrentlyAuthenticatedAndLoggedInUserObject are unwieldy.

async function startSession(emailAddressOfTheUser, plainTextPasswordEnteredByTheUser) {
  const theUserAccountThatWasLookedUpFromTheDatabase = await fetchUserByEmail(emailAddressOfTheUser);

  const isPasswordCorrectAndMatchesTheStoredHash = await verifyPassword(
    plainTextPasswordEnteredByTheUser,
    theUserAccountThatWasLookedUpFromTheDatabase.passwordHash
  );

  if (!isPasswordCorrectAndMatchesTheStoredHash) {
    throw new Error('Invalid credentials');
  }

  const theNewlyGeneratedSessionTokenString = generateSecureRandomSessionToken();
  const theSessionExpiryTimestampInUtc = new Date(Date.now() + 86_400_000);

  return {
    token: theNewlyGeneratedSessionTokenString,
    expiresAt: theSessionExpiryTimestampInUtc,
    userId: theUserAccountThatWasLookedUpFromTheDatabase.id,
  };
}

async function validateSession(theSessionTokenStringProvidedByTheClient) {
  const theSessionRecordRetrievedFromTheDatabase =
    await lookupSessionInDatabase(theSessionTokenStringProvidedByTheClient);

  const theCurrentDateAndTimeInUtcTimezone = new Date();

  if (theCurrentDateAndTimeInUtcTimezone > theSessionRecordRetrievedFromTheDatabase.expiresAt) {
    throw new Error('Session expired');
  }

  return theSessionRecordRetrievedFromTheDatabase;
}

async function refreshSession(theExistingSessionTokenThatNeedsToBeRefreshed) {
  const theCurrentSessionDataFromTheDatabase =
    await validateSession(theExistingSessionTokenThatNeedsToBeRefreshed);

  const theNewSessionTokenThatReplacesTheOldOne = generateSecureRandomSessionToken();
  const theUpdatedExpiryTimeForTheRefreshedSession = new Date(Date.now() + 86_400_000);

  return {
    token: theNewSessionTokenThatReplacesTheOldOne,
    expiresAt: theUpdatedExpiryTimeForTheRefreshedSession,
    userId: theCurrentSessionDataFromTheDatabase.userId,
  };
}

async function listActiveSessions(theUniqueIdentifierOfTheUserAccount) {
  const theMaximumAllowedNumberOfRetryAttemptsBeforeGivingUp = 3;
  const theCompleteListOfAllSessionsBelongingToTheSpecifiedUser = await fetchAllSessionsForUser(
    theUniqueIdentifierOfTheUserAccount,
    theMaximumAllowedNumberOfRetryAttemptsBeforeGivingUp
  );

  const theCurrentTimestampUsedToFilterExpiredSessions = new Date();

  return theCompleteListOfAllSessionsBelongingToTheSpecifiedUser.filter(
    eachIndividualSessionRecord =>
      eachIndividualSessionRecord.expiresAt > theCurrentTimestampUsedToFilterExpiredSessions
  );
}

async function getCurrentlyAuthenticatedAndLoggedInUserObject(theSessionTokenStringProvidedByTheClient) {
  const theValidatedSessionRecordFromTheDatabase =
    await validateSession(theSessionTokenStringProvidedByTheClient);
  return fetchUserByIdFromTheDatabase(theValidatedSessionRecordFromTheDatabase.userId);
}

async function fetchUserByEmail(email) { return { id: 1, email, passwordHash: 'hash' }; }
async function verifyPassword(password) { return password.length > 0; }
function generateSecureRandomSessionToken() { return Math.random().toString(36).slice(2); }
async function lookupSessionInDatabase() { return { userId: 1, expiresAt: new Date(Date.now() + 3600_000) }; }
async function fetchAllSessionsForUser() { return []; }
async function fetchUserByIdFromTheDatabase(id) { return { id }; }

module.exports = { startSession, validateSession, refreshSession, listActiveSessions, getCurrentlyAuthenticatedAndLoggedInUserObject };
