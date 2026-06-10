const listeners = new Set();
let state = {};

export function getState(key) {
  if (key == null) return state;
  return state[key];
}

export function setState(patch) {
  if (!patch || typeof patch !== "object") return;
  state = { ...state, ...patch };
  listeners.forEach((fn) => fn(state));
}

export function subscribe(fn) {
  if (typeof fn !== "function") return () => {};
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function reset() {
  state = {};
  listeners.clear();
}

export function selectVisible(items, filter) {
  if (!filter) return items;
  return items.filter((item) => item.label.includes(filter));
}
