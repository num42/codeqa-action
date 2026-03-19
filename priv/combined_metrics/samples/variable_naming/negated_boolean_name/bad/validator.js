// Form and data validation using negated boolean variable names.
// BAD: isNotValid, notActive, isDisabled, noAccess, notFound — double negatives obscure logic.

function validateUser(user) {
  const isNotValidEmail = !isValidEmail(user.email);
  const notActiveAccount = user.status !== 'active';
  const isNotEmptyName = !user.name || user.name.trim() === '';

  const errors = [];
  if (isNotValidEmail) errors.push('Email is invalid');
  if (notActiveAccount) errors.push('Account is not active');
  if (isNotEmptyName) errors.push('Name cannot be blank');

  return errors.length === 0 ? { ok: true, data: user } : { ok: false, errors };
}

function checkAccess(user, resource) {
  const noAccess = !['admin', 'editor'].includes(user.role);
  const isDisabled = user.status === 'disabled';
  const notFound = !resourceExists(resource);

  return !(noAccess || isDisabled || notFound);
}

function validatePayment(payment) {
  const isNotValidAmount = payment.amount <= 0;
  const notSupportedCurrency = !['USD', 'EUR', 'GBP'].includes(payment.currency);
  const isExpiredCard = isCardExpired(payment.card);

  if (isNotValidAmount) return { ok: false, error: 'Amount must be positive' };
  if (notSupportedCurrency) return { ok: false, error: 'Currency not supported' };
  if (isExpiredCard) return { ok: false, error: 'Card has expired' };

  return { ok: true, data: payment };
}

function validatePassword(password) {
  const isNotLongEnough = password.length < 8;
  const isNotComplexEnough = !hasSpecialChar(password);
  const noUppercase = !hasUppercase(password);
  const noDigit = !hasDigit(password);

  const errors = [];
  if (isNotLongEnough) errors.push('Must be at least 8 characters');
  if (isNotComplexEnough) errors.push('Must contain a special character');
  if (noUppercase) errors.push('Must contain an uppercase letter');
  if (noDigit) errors.push('Must contain a digit');

  return errors.length === 0 ? { ok: true } : { ok: false, errors };
}

function validateForm(form) {
  const isNotValidEmail = !isValidEmail(form.email || '');
  const notAcceptedTerms = !form.termsAccepted;
  const isNotEmptyMessage = !form.message || form.message.trim() === '';

  const errors = {};
  if (isNotValidEmail) errors.email = 'Invalid email';
  if (notAcceptedTerms) errors.terms = 'Must accept terms';
  if (isNotEmptyMessage) errors.message = 'Message is required';

  return Object.keys(errors).length === 0 ? { ok: true, data: form } : { ok: false, errors };
}

function validateAddress(address) {
  const isNotPresent = !address.street || address.street.trim() === '';
  const noPostalCode = !address.postalCode;
  const isNotValidCountry = !isSupportedCountry(address.country);

  return {
    isValid: !isNotPresent && !noPostalCode && !isNotValidCountry,
    missingStreet: isNotPresent,
    missingPostalCode: noPostalCode,
    unsupportedCountry: isNotValidCountry,
  };
}

function isValidEmail(email) { return email.includes('@'); }
function resourceExists() { return true; }
function isCardExpired() { return false; }
function hasSpecialChar(pw) { return /[!@#$%^&*]/.test(pw); }
function hasUppercase(pw) { return /[A-Z]/.test(pw); }
function hasDigit(pw) { return /\d/.test(pw); }
function isSupportedCountry(country) { return ['US', 'DE', 'GB'].includes(country); }

module.exports = { validateUser, checkAccess, validatePayment, validatePassword, validateForm, validateAddress };
