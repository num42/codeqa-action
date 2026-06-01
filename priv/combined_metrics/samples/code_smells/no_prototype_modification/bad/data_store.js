Array.prototype.groupBy = function (keyFn) {
  return this.reduce((groups, item) => {
    const key = keyFn(item);
    if (!groups[key]) groups[key] = [];
    groups[key].push(item);
    return groups;
  }, {});
};

Array.prototype.unique = function (keyFn = (x) => x) {
  const seen = new Set();
  return this.filter((item) => {
    const key = keyFn(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

Array.prototype.sortedBy = function (keyFn, direction = "asc") {
  const multiplier = direction === "asc" ? 1 : -1;
  return [...this].sort((a, b) => {
    const ak = keyFn(a);
    const bk = keyFn(b);
    return ak < bk ? -multiplier : ak > bk ? multiplier : 0;
  });
};

Object.prototype.deepClone = function () {
  return JSON.parse(JSON.stringify(this));
};

String.prototype.toTitleCase = function () {
  return this.replace(/\b\w/g, (c) => c.toUpperCase());
};

class DataStore {
  constructor(records = []) {
    this._records = [...records];
  }

  add(record) {
    this._records.push(record);
  }

  findBy(predicate) {
    return this._records.filter(predicate);
  }

  groupBy(keyFn) {
    return this._records.groupBy(keyFn);
  }

  sortedBy(keyFn, direction) {
    return this._records.sortedBy(keyFn, direction);
  }

  get size() {
    return this._records.length;
  }
}

export { DataStore };
