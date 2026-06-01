# Form and data validation using negated boolean variable names.
# BAD: is_not_valid, not_active, is_disabled, no_access, not_found — double negatives obscure logic.

class ValidatorBad
  def validate_user(user)
    is_not_valid_email = !valid_email?(user[:email])
    not_active_account = user[:status] != :active
    is_not_empty_name = user[:name].nil? || user[:name].strip.empty?

    errors = []
    errors << 'Email is invalid' if is_not_valid_email
    errors << 'Account is not active' if not_active_account
    errors << 'Name cannot be blank' if is_not_empty_name

    errors.empty? ? { ok: true, data: user } : { ok: false, errors: errors }
  end

  def check_access(user, resource)
    no_access = !%i[admin editor].include?(user[:role])
    is_disabled = user[:status] == :disabled
    not_found = !resource_exists?(resource)

    !(no_access || is_disabled || not_found)
  end

  def validate_payment(payment)
    is_not_valid_amount = payment[:amount] <= 0
    not_supported_currency = !%w[USD EUR GBP].include?(payment[:currency])
    is_expired_card = card_expired?(payment[:card])

    return { ok: false, error: 'Amount must be positive' } if is_not_valid_amount
    return { ok: false, error: 'Currency not supported' } if not_supported_currency
    return { ok: false, error: 'Card has expired' } if is_expired_card

    { ok: true, data: payment }
  end

  def validate_password(password)
    is_not_long_enough = password.length < 8
    is_not_complex_enough = !has_special_char?(password)
    no_uppercase = !has_uppercase?(password)
    no_digit = !has_digit?(password)

    errors = []
    errors << 'Must be at least 8 characters' if is_not_long_enough
    errors << 'Must contain a special character' if is_not_complex_enough
    errors << 'Must contain an uppercase letter' if no_uppercase
    errors << 'Must contain a digit' if no_digit

    errors.empty? ? { ok: true } : { ok: false, errors: errors }
  end

  def validate_form(form)
    is_not_valid_email = !valid_email?(form[:email] || '')
    not_accepted_terms = !form[:terms_accepted]
    is_not_empty_message = form[:message].nil? || form[:message].strip.empty?

    errors = {}
    errors[:email] = 'Invalid email' if is_not_valid_email
    errors[:terms] = 'Must accept terms' if not_accepted_terms
    errors[:message] = 'Message is required' if is_not_empty_message

    errors.empty? ? { ok: true, data: form } : { ok: false, errors: errors }
  end

  def validate_address(address)
    is_not_present = address[:street].nil? || address[:street].strip.empty?
    no_postal_code = address[:postal_code].nil?
    is_not_valid_country = !supported_country?(address[:country])

    {
      is_valid: !is_not_present && !no_postal_code && !is_not_valid_country,
      missing_street: is_not_present,
      missing_postal_code: no_postal_code,
      unsupported_country: is_not_valid_country
    }
  end

  private

  def valid_email?(email) = email.include?('@')
  def resource_exists?(_resource) = true
  def card_expired?(_card) = false
  def has_special_char?(pw) = pw.match?(/[!@#$%^&*]/)
  def has_uppercase?(pw) = pw.match?(/[A-Z]/)
  def has_digit?(pw) = pw.match?(/\d/)
  def supported_country?(country) = %w[US DE GB].include?(country)
end
