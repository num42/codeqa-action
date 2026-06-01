// Form and data validation using positive boolean variable names.
// GOOD: isValid, isActive, isEnabled, hasAccess, isFound — positive names read naturally.

function validateUser(user) {
  const isValidEmail = checkValidEmail(user.email);
  const isActiveAccount = user.status === 'active';
  const hasName = user.name && user.name.trim() !== '';

  const errors = [];
  if (!isValidEmail) errors.push('Email is invalid');
  if (!isActiveAccount) errors.push('Account is not active');
  if (!hasName) errors.push('Name cannot be blank');

  return errors.length === 0 ? { ok: true, data: user } : { ok: false, errors };
}

function checkAccess(user, resource) {
  const hasAccess = ['admin', 'editor'].includes(user.role);
  const isEnabled = user.status !== 'disabled';
  const isFound = resourceExists(resource);

  return hasAccess && isEnabled && isFound;
}

function validatePayment(payment) {
  const isValidAmount = payment.amount > 0;
  const isSupportedCurrency = ['USD', 'EUR', 'GBP'].includes(payment.currency);
  const isValidCard = !isCardExpired(payment.card);

  if (!isValidAmount) return { ok: false, error: 'Amount must be positive' };
  if (!isSupportedCurrency) return { ok: false, error: 'Currency not supported' };
  if (!isValidCard) return { ok: false, error: 'Card has expired' };

  return { ok: true, data: payment };
}

function validatePassword(password) {
  const isLongEnough = password.length >= 8;
  const isComplexEnough = hasSpecialChar(password);
  const hasUppercase = hasUppercaseChar(password);
  const hasDigit = hasDigitChar(password);

  const errors = [];
  if (!isLongEnough) errors.push('Must be at least 8 characters');
  if (!isComplexEnough) errors.push('Must contain a special character');
  if (!hasUppercase) errors.push('Must contain an uppercase letter');
  if (!hasDigit) errors.push('Must contain a digit');

  return errors.length === 0 ? { ok: true } : { ok: false, errors };
}

function validateForm(form) {
  const isValidEmail = checkValidEmail(form.email || '');
  const hasAcceptedTerms = form.termsAccepted === true;
  const hasMessage = form.message && form.message.trim() !== '';

  const errors = {};
  if (!isValidEmail) errors.email = 'Invalid email';
  if (!hasAcceptedTerms) errors.terms = 'Must accept terms';
  if (!hasMessage) errors.message = 'Message is required';

  return Object.keys(errors).length === 0 ? { ok: true, data: form } : { ok: false, errors };
}

function validateAddress(address) {
  const hasStreet = address.street && address.street.trim() !== '';
  const hasPostalCode = !!address.postalCode;
  const isSupportedCountry = checkSupportedCountry(address.country);

  return {
    isValid: hasStreet && hasPostalCode && isSupportedCountry,
    hasStreet,
    hasPostalCode,
    isSupportedCountry,
  };
}

function checkValidEmail(email) { return email.includes('@'); }
function resourceExists() { return true; }
function isCardExpired() { return false; }
function hasSpecialChar(pw) { return /[!@#$%^&*]/.test(pw); }
function hasUppercaseChar(pw) { return /[A-Z]/.test(pw); }
function hasDigitChar(pw) { return /\d/.test(pw); }
function checkSupportedCountry(country) { return ['US', 'DE', 'GB'].includes(country); }

module.exports = { validateUser, checkAccess, validatePayment, validatePassword, validateForm, validateAddress };
