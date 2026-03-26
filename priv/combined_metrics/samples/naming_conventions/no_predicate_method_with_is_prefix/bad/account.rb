class Account
  TRIAL_DAYS = 14

  attr_reader :role, :status, :verified_at, :suspended_at, :created_at, :plan

  def initialize(attrs = {})
    @role = attrs[:role]
    @status = attrs[:status] || :pending
    @verified_at = attrs[:verified_at]
    @suspended_at = attrs[:suspended_at]
    @created_at = attrs[:created_at] || Time.current
    @plan = attrs[:plan] || :free
  end

  # Forbidden `is_` prefix on predicate methods
  def is_admin?
    role == :admin
  end

  def is_verified?
    verified_at.present?
  end

  def is_suspended?
    suspended_at.present?
  end

  def is_active?
    status == :active && !is_suspended?
  end

  def is_on_trial?
    created_at > TRIAL_DAYS.days.ago && plan == :free
  end

  # `can_` prefix also violates the convention
  def can_access_premium?
    is_active? && !is_on_trial?
  end

  # `does_` prefix also violates the convention
  def does_need_verification?
    !is_verified? && is_active?
  end

  def eligible_for_upgrade?
    !can_access_premium? && is_verified? && !is_suspended?
  end
end
