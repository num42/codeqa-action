function groupBy(array, keyFn) {
  return array.reduce((groups, item) => {
    const key = keyFn(item);
    if (!Object.prototype.hasOwnProperty.call(groups, key)) {
      groups[key] = [];
    }
    groups[key].push(item);
    return groups;
  }, {});
}

function unique(array, keyFn = (x) => x) {
  const seen = new Set();
  return array.filter((item) => {
    const key = keyFn(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function sortedBy(array, keyFn, direction = "asc") {
  const multiplier = direction === "asc" ? 1 : -1;
  return [...array].sort((a, b) => {
    const ak = keyFn(a);
    const bk = keyFn(b);
    return ak < bk ? -multiplier : ak > bk ? multiplier : 0;
  });
}

class DataStore {
  constructor(records = []) {
    this._records = [...records];
    this._indexes = new Map();
  }

  add(record) {
    this._records.push(record);
    this._invalidateIndexes();
  }

  findBy(predicate) {
    return this._records.filter(predicate);
  }

  groupBy(keyFn) {
    return groupBy(this._records, keyFn);
  }

  sortedBy(keyFn, direction) {
    return sortedBy(this._records, keyFn, direction);
  }

  unique(keyFn) {
    return unique(this._records, keyFn);
  }

  _invalidateIndexes() {
    this._indexes.clear();
  }

  get size() {
    return this._records.length;
  }
}

export { DataStore, groupBy, unique, sortedBy };
