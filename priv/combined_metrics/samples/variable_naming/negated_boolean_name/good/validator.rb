# Form and data validation using positive boolean variable names.
# GOOD: is_valid, is_active, is_enabled, has_access, is_found — positive names read naturally.

class ValidatorGood
  def validate_user(user)
    is_valid_email = valid_email?(user[:email])
    is_active_account = user[:status] == :active
    has_name = !user[:name].nil? && !user[:name].strip.empty?

    errors = []
    errors << 'Email is invalid' unless is_valid_email
    errors << 'Account is not active' unless is_active_account
    errors << 'Name cannot be blank' unless has_name

    errors.empty? ? { ok: true, data: user } : { ok: false, errors: errors }
  end

  def check_access(user, resource)
    has_access = %i[admin editor].include?(user[:role])
    is_enabled = user[:status] != :disabled
    is_found = resource_exists?(resource)

    has_access && is_enabled && is_found
  end

  def validate_payment(payment)
    is_valid_amount = payment[:amount] > 0
    is_supported_currency = %w[USD EUR GBP].include?(payment[:currency])
    is_valid_card = !card_expired?(payment[:card])

    return { ok: false, error: 'Amount must be positive' } unless is_valid_amount
    return { ok: false, error: 'Currency not supported' } unless is_supported_currency
    return { ok: false, error: 'Card has expired' } unless is_valid_card

    { ok: true, data: payment }
  end

  def validate_password(password)
    is_long_enough = password.length >= 8
    is_complex_enough = has_special_char?(password)
    has_uppercase = has_uppercase_char?(password)
    has_digit = has_digit_char?(password)

    errors = []
    errors << 'Must be at least 8 characters' unless is_long_enough
    errors << 'Must contain a special character' unless is_complex_enough
    errors << 'Must contain an uppercase letter' unless has_uppercase
    errors << 'Must contain a digit' unless has_digit

    errors.empty? ? { ok: true } : { ok: false, errors: errors }
  end

  def validate_form(form)
    is_valid_email = valid_email?(form[:email] || '')
    has_accepted_terms = form[:terms_accepted] == true
    has_message = !form[:message].nil? && !form[:message].strip.empty?

    errors = {}
    errors[:email] = 'Invalid email' unless is_valid_email
    errors[:terms] = 'Must accept terms' unless has_accepted_terms
    errors[:message] = 'Message is required' unless has_message

    errors.empty? ? { ok: true, data: form } : { ok: false, errors: errors }
  end

  def validate_address(address)
    has_street = !address[:street].nil? && !address[:street].strip.empty?
    has_postal_code = !address[:postal_code].nil?
    is_supported_country = supported_country?(address[:country])

    {
      is_valid: has_street && has_postal_code && is_supported_country,
      has_street: has_street,
      has_postal_code: has_postal_code,
      is_supported_country: is_supported_country
    }
  end

  private

  def valid_email?(email) = email.include?('@')
  def resource_exists?(_resource) = true
  def card_expired?(_card) = false
  def has_special_char?(pw) = pw.match?(/[!@#$%^&*]/)
  def has_uppercase_char?(pw) = pw.match?(/[A-Z]/)
  def has_digit_char?(pw) = pw.match?(/\d/)
  def supported_country?(country) = %w[US DE GB].include?(country)
end
