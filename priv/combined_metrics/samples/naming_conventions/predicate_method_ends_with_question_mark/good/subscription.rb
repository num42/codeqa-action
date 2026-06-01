class Subscription
  GRACE_PERIOD_DAYS = 3

  attr_reader :status, :plan, :expires_at, :payment_method, :trial_ends_at

  def initialize(attrs = {})
    @status = attrs[:status]
    @plan = attrs[:plan]
    @expires_at = attrs[:expires_at]
    @payment_method = attrs[:payment_method]
    @trial_ends_at = attrs[:trial_ends_at]
    @cancelled_at = attrs[:cancelled_at]
  end

  def active?
    status == :active && !expired?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def in_grace_period?
    expired? && expires_at >= GRACE_PERIOD_DAYS.days.ago
  end

  def trialing?
    trial_ends_at.present? && trial_ends_at > Time.current
  end

  def cancelled?
    status == :cancelled
  end

  def paid?
    plan.present? && plan != :free
  end

  def payment_method_expiring_soon?
    return false unless payment_method
    payment_method.expires_at < 30.days.from_now
  end

  def eligible_for_discount?
    paid? && !cancelled? && !trialing?
  end

  def renewable?
    (active? || in_grace_period?) && !cancelled?
  end
end
