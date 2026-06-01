class PaymentMethod
  attr_reader :id, :card_type, :last_four, :expires_at, :billing_address
  attr_accessor :nickname, :is_default

  def initialize(attrs = {})
    @id = attrs[:id]
    @card_type = attrs[:card_type]
    @last_four = attrs[:last_four]
    @expires_at = attrs[:expires_at]
    @billing_address = attrs[:billing_address]
    @nickname = attrs[:nickname]
    @is_default = attrs[:is_default] || false
  end

  def expired?
    expires_at < Date.today
  end

  def expiring_soon?
    !expired? && expires_at < 30.days.from_now
  end

  def display_name
    base = "#{card_type.upcase} ending in #{last_four}"
    nickname ? "#{nickname} (#{base})" : base
  end

  def to_h
    {
      id: id,
      card_type: card_type,
      last_four: last_four,
      expires_at: expires_at,
      nickname: nickname,
      is_default: is_default,
      expired: expired?
    }
  end
end
