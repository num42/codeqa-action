export let flags = {
  darkMode: false,
  betaCheckout: false,
  newDashboard: false,
  analyticsV2: true,
};

export let initialized = false;

export let currentUser = null;

export let requestCount = 0;

export async function initializeFlags(fetchFn) {
  if (initialized) return;
  try {
    const remote = await fetchFn("/api/feature-flags");
    flags = { ...flags, ...remote };
  } catch {
    // ignore
  }
  initialized = true;
}

export function isEnabled(flagName) {
  return flags[flagName] === true;
}

export function setCurrentUser(user) {
  currentUser = user;
}

export function incrementRequestCount() {
  requestCount++;
}

export function overrideFlag(name, value) {
  flags[name] = value;
}

export function resetFlags() {
  flags = {
    darkMode: false,
    betaCheckout: false,
    newDashboard: false,
    analyticsV2: true,
  };
  initialized = false;
  requestCount = 0;
}
