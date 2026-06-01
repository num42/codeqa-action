const DEFAULT_FLAGS = {
  darkMode: false,
  betaCheckout: false,
  newDashboard: false,
  analyticsV2: true,
};

let _flags = { ...DEFAULT_FLAGS };
let _initialized = false;

export async function initializeFlags(fetchFn) {
  if (_initialized) return;
  try {
    const remote = await fetchFn("/api/feature-flags");
    _flags = { ...DEFAULT_FLAGS, ...remote };
  } catch {
    // Remote fetch failed; fall back to defaults silently
    _flags = { ...DEFAULT_FLAGS };
  }
  _initialized = true;
}

export function isEnabled(flagName) {
  return _flags[flagName] === true;
}

export function getFlags() {
  return { ..._flags };
}

export function overrideFlag(name, value) {
  if (!(name in DEFAULT_FLAGS)) {
    throw new Error(`Unknown feature flag: '${name}'`);
  }
  _flags = { ..._flags, [name]: value };
}

export function resetFlags() {
  _flags = { ...DEFAULT_FLAGS };
  _initialized = false;
}

export const FLAG_NAMES = Object.freeze(Object.keys(DEFAULT_FLAGS));
