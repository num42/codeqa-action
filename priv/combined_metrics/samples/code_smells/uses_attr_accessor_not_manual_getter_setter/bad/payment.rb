class PaymentMethod
  def initialize(attrs = {})
    @id = attrs[:id]
    @card_type = attrs[:card_type]
    @last_four = attrs[:last_four]
    @expires_at = attrs[:expires_at]
    @billing_address = attrs[:billing_address]
    @nickname = attrs[:nickname]
    @is_default = attrs[:is_default] || false
  end

  # Manual getters — should use attr_reader
  def id
    @id
  end

  def card_type
    @card_type
  end

  def last_four
    @last_four
  end

  def expires_at
    @expires_at
  end

  def billing_address
    @billing_address
  end

  # Manual getter + setter pair — should use attr_accessor
  def nickname
    @nickname
  end

  def nickname=(value)
    @nickname = value
  end

  def is_default
    @is_default
  end

  def is_default=(value)
    @is_default = value
  end

  def expired?
    @expires_at < Date.today
  end

  def display_name
    base = "#{@card_type.upcase} ending in #{@last_four}"
    @nickname ? "#{@nickname} (#{base})" : base
  end
end
