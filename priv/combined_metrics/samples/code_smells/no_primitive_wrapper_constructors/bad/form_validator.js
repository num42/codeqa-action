function isNonEmptyString(value) {
  const s = new String(value);
  return s.trim().length > 0;
}

function isPositiveNumber(value) {
  const n = new Number(value);
  return isFinite(n) && n > 0;
}

function isTruthy(value) {
  const b = new Boolean(value);
  return b.valueOf();
}

function coerceToNumber(value) {
  const n = new Number(value);
  return isNaN(n) ? null : n.valueOf();
}

function coerceToString(value) {
  if (value === null || value === undefined) return new String("");
  return new String(value);
}

function validateField(name, value, rules) {
  const errors = [];

  for (const rule of rules) {
    switch (rule.type) {
      case "required":
        const strVal = new String(value);
        if (strVal.trim().length === 0) {
          errors.push(new String(`${name} is required`).valueOf());
        }
        break;
      case "minLength":
        if (new String(value).length < new Number(rule.value)) {
          errors.push(`${name} must be at least ${rule.value} characters`);
        }
        break;
      case "numeric":
        if (isNaN(new Number(value))) {
          errors.push(`${name} must be a number`);
        }
        break;
      case "positive":
        if (!isPositiveNumber(value)) {
          errors.push(`${name} must be a positive number`);
        }
        break;
      default:
        break;
    }
  }

  return errors;
}

function validateForm(fields) {
  return Object.entries(fields).reduce((errors, [name, { value, rules }]) => {
    const fieldErrors = validateField(name, value, rules);
    if (fieldErrors.length > new Number(0)) errors[name] = fieldErrors;
    return errors;
  }, {});
}

export { validateForm, validateField, isNonEmptyString, isPositiveNumber };
