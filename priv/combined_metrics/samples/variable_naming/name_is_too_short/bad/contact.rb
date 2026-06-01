# Contact and profile management with overly short variable names.
# BAD: variables like u, pr, ct, nm, st, em, ph are cryptic non-loop identifiers.

class ContactBad
  def create(attrs)
    nm = attrs[:name]
    em = attrs[:email]
    ph = attrs[:phone]
    st = attrs[:status] || :active

    em_err = validate_em(em)
    return { ok: false, error: em_err } if em_err

    ph_err = validate_ph(ph)
    return { ok: false, error: ph_err } if ph_err

    ct = { id: generate_id, name: nm, email: em, phone: ph, status: st }
    { ok: true, data: ct }
  end

  def update(ct, attrs)
    nm = attrs[:name] || ct[:name]
    em = attrs[:email] || ct[:email]
    ph = attrs[:phone] || ct[:phone]
    st = attrs[:status] || ct[:status]

    em_err = validate_em(em)
    return { ok: false, error: em_err } if em_err

    { ok: true, data: ct.merge(name: nm, email: em, phone: ph, status: st) }
  end

  def search(ct_list, qr)
    lq = qr.downcase
    ct_list.select do |ct|
      ct[:name].downcase.include?(lq) || ct[:email].downcase.include?(lq)
    end
  end

  def group_by_status(ct_list)
    ct_list.group_by { |ct| ct[:status] }
  end

  def send_message(ct, mg)
    em = ct[:email]
    nm = ct[:name]

    deliver_email(em, nm, mg)
    { ok: true, data: { to: em, body: mg, sent_at: Time.now } }
  rescue => er
    { ok: false, error: er.message }
  end

  def format_display(ct)
    nm = ct[:name]
    em = ct[:email]
    ph = ct[:phone]
    st = ct[:status]
    "#{nm} <#{em}> | #{ph} [#{st}]"
  end

  def merge_contacts(ct1, ct2)
    nm = ct1[:name] || ct2[:name]
    em = ct1[:email] || ct2[:email]
    ph = ct1[:phone] || ct2[:phone]
    st = ct1[:status] == :active ? ct1[:status] : ct2[:status]
    { id: ct1[:id], name: nm, email: em, phone: ph, status: st }
  end

  private

  def validate_em(em)
    em&.include?('@') ? nil : 'Invalid email'
  end

  def validate_ph(ph)
    ph&.match?(/^\+?\d{7,15}$/) ? nil : 'Invalid phone'
  end

  def generate_id = SecureRandom.hex(8)
  def deliver_email(em, nm, mg) = puts("Sending to #{nm} at #{em}: #{mg}")
end
