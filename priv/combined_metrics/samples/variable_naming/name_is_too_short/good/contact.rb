# Contact and profile management with clear, readable variable names.
# GOOD: user, price, count, name, status, email, phone — obvious at a glance.

class ContactGood
  def create(attrs)
    name = attrs[:name]
    email = attrs[:email]
    phone = attrs[:phone]
    status = attrs[:status] || :active

    email_error = validate_email(email)
    return { ok: false, error: email_error } if email_error

    phone_error = validate_phone(phone)
    return { ok: false, error: phone_error } if phone_error

    contact = { id: generate_id, name: name, email: email, phone: phone, status: status }
    { ok: true, data: contact }
  end

  def update(contact, attrs)
    name = attrs[:name] || contact[:name]
    email = attrs[:email] || contact[:email]
    phone = attrs[:phone] || contact[:phone]
    status = attrs[:status] || contact[:status]

    email_error = validate_email(email)
    return { ok: false, error: email_error } if email_error

    { ok: true, data: contact.merge(name: name, email: email, phone: phone, status: status) }
  end

  def search(contacts, query)
    lower_query = query.downcase
    contacts.select do |contact|
      contact[:name].downcase.include?(lower_query) || contact[:email].downcase.include?(lower_query)
    end
  end

  def group_by_status(contacts)
    contacts.group_by { |contact| contact[:status] }
  end

  def send_message(contact, message)
    email = contact[:email]
    name = contact[:name]

    deliver_email(email, name, message)
    { ok: true, data: { to: email, body: message, sent_at: Time.now } }
  rescue => error
    { ok: false, error: error.message }
  end

  def format_display(contact)
    name = contact[:name]
    email = contact[:email]
    phone = contact[:phone]
    status = contact[:status]
    "#{name} <#{email}> | #{phone} [#{status}]"
  end

  def merge_contacts(primary, secondary)
    name = primary[:name] || secondary[:name]
    email = primary[:email] || secondary[:email]
    phone = primary[:phone] || secondary[:phone]
    status = primary[:status] == :active ? primary[:status] : secondary[:status]
    { id: primary[:id], name: name, email: email, phone: phone, status: status }
  end

  private

  def validate_email(email)
    email&.include?('@') ? nil : 'Invalid email'
  end

  def validate_phone(phone)
    phone&.match?(/^\+?\d{7,15}$/) ? nil : 'Invalid phone'
  end

  def generate_id = SecureRandom.hex(8)
  def deliver_email(email, name, message) = puts("Sending to #{name} at #{email}: #{message}")
end
