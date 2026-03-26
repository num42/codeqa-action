function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isPositiveNumber(value) {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function isTruthy(value) {
  return Boolean(value);
}

function coerceToNumber(value) {
  const n = Number(value);
  return Number.isNaN(n) ? null : n;
}

function coerceToString(value) {
  if (value === null || value === undefined) return "";
  return String(value);
}

function validateField(name, value, rules) {
  const errors = [];

  for (const rule of rules) {
    switch (rule.type) {
      case "required":
        if (!isNonEmptyString(coerceToString(value))) {
          errors.push(`${name} is required`);
        }
        break;
      case "minLength":
        if (typeof value === "string" && value.length < rule.value) {
          errors.push(`${name} must be at least ${rule.value} characters`);
        }
        break;
      case "numeric":
        if (coerceToNumber(value) === null) {
          errors.push(`${name} must be a number`);
        }
        break;
      case "positive":
        if (!isPositiveNumber(coerceToNumber(value))) {
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
    if (fieldErrors.length > 0) errors[name] = fieldErrors;
    return errors;
  }, {});
}

export { validateForm, validateField, isNonEmptyString, isPositiveNumber, coerceToNumber, coerceToString };
