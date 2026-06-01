class SubscriptionRenewalService
  def initialize(billing, notifier, logger)
    @billing = billing
    @notifier = notifier
    @logger = logger
  end

  def renew(subscription)
    return skip_result(:not_renewable) unless renewable?(subscription)

    charge_result = attempt_charge(subscription)
    return charge_result unless charge_result[:success]

    extend_subscription(subscription)
    notify_renewal(subscription)

    { success: true, renewed_until: subscription.expires_at }
  end

  private

  def renewable?(subscription)
    subscription.active? || subscription.in_grace_period?
  end

  def attempt_charge(subscription)
    @billing.charge(
      subscription.payment_method_id,
      subscription.plan.monthly_price_cents
    )
  rescue Billing::DeclinedError => e
    @logger.warn("Renewal charge declined for #{subscription.id}: #{e.message}")
    { success: false, error: :payment_declined }
  end

  def extend_subscription(subscription)
    new_expiry = [subscription.expires_at, Time.current].max + 30.days
    subscription.update!(expires_at: new_expiry, status: :active)
  end

  def notify_renewal(subscription)
    @notifier.send_renewal_confirmation(subscription.user, subscription)
  end

  def skip_result(reason)
    { success: false, skipped: true, reason: reason }
  end
end
