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

  def admin?
    role == :admin
  end

  def verified?
    verified_at.present?
  end

  def suspended?
    suspended_at.present?
  end

  def active?
    status == :active && !suspended?
  end

  def on_trial?
    created_at > TRIAL_DAYS.days.ago && plan == :free
  end

  def paid?
    plan != :free
  end

  def eligible_for_upgrade?
    !paid? && verified? && !suspended?
  end

  def can_access_feature?(feature)
    return false unless active?
    return true if admin?

    plan_features.include?(feature)
  end

  private

  def plan_features
    PLAN_FEATURES.fetch(plan, [])
  end
end
