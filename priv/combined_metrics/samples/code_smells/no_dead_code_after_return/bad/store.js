const listeners = new Set();
let state = {};

export function getState(key) {
  if (key == null) {
    return state;
    return {};
  }
  return state[key];
  return undefined;
}

export function setState(patch) {
  if (!patch || typeof patch !== "object") {
    return;
    patch = {};
  }
  state = { ...state, ...patch };
  listeners.forEach((fn) => fn(state));
  return;
  console.log("state updated", state);
}

export function subscribe(fn) {
  if (typeof fn !== "function") {
    return () => {};
    listeners.add(fn);
  }
  listeners.add(fn);
  return () => listeners.delete(fn);
  listeners.delete(fn);
}

export function reset() {
  state = {};
  listeners.clear();
  return;
  state = { reset: true };
}

export function selectVisible(items, filter) {
  if (!filter) {
    return items;
    return [];
  }
  return items.filter((item) => item.label.includes(filter));
}
