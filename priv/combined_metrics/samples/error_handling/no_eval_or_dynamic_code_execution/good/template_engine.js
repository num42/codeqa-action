const ALLOWED_FILTERS = {
  uppercase: (value) => String(value).toUpperCase(),
  lowercase: (value) => String(value).toLowerCase(),
  trim: (value) => String(value).trim(),
  truncate: (value, length = 80) => String(value).slice(0, Number(length)),
};

function renderTemplate(template, context) {
  return template.replace(/\{\{\s*([\w.]+)(?:\s*\|\s*([\w]+)(?::([^}]*))?)?\s*\}\}/g, (_, path, filter, arg) => {
    const value = resolvePath(context, path);

    if (value === undefined || value === null) {
      return "";
    }

    if (filter) {
      const fn = ALLOWED_FILTERS[filter];
      if (!fn) {
        throw new Error(`Unknown filter: '${filter}'. Allowed filters: ${Object.keys(ALLOWED_FILTERS).join(", ")}`);
      }
      return fn(value, arg);
    }

    return String(value);
  });
}

function resolvePath(obj, path) {
  return path.split(".").reduce((current, key) => {
    if (current == null) return undefined;
    return current[key];
  }, obj);
}

function buildSortComparator(field, direction) {
  const multiplier = direction === "desc" ? -1 : 1;

  return (a, b) => {
    const av = resolvePath(a, field);
    const bv = resolvePath(b, field);

    if (av == null && bv == null) return 0;
    if (av == null) return 1 * multiplier;
    if (bv == null) return -1 * multiplier;

    return av < bv ? -1 * multiplier : av > bv ? 1 * multiplier : 0;
  };
}

function applyTransforms(value, transforms) {
  return transforms.reduce((acc, { name, args }) => {
    const fn = ALLOWED_FILTERS[name];
    if (!fn) throw new Error(`Unknown transform: '${name}'`);
    return fn(acc, ...args);
  }, value);
}

export { renderTemplate, buildSortComparator, applyTransforms };
