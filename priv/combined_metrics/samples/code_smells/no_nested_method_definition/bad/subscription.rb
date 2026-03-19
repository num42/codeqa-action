class SubscriptionRenewalService
  def initialize(billing, notifier, logger)
    @billing = billing
    @notifier = notifier
    @logger = logger
  end

  def renew(subscription)
    # Methods defined inside another method do NOT create closures in Ruby.
    # They are defined on the enclosing class/object, not scoped locally.
    def renewable?(sub)
      sub.active? || sub.in_grace_period?
    end

    def attempt_charge(sub)
      @billing.charge(
        sub.payment_method_id,
        sub.plan.monthly_price_cents
      )
    rescue Billing::DeclinedError => e
      { success: false, error: :payment_declined }
    end

    def extend_subscription(sub)
      new_expiry = [sub.expires_at, Time.current].max + 30.days
      sub.update!(expires_at: new_expiry, status: :active)
    end

    return { success: false, skipped: true } unless renewable?(subscription)

    charge_result = attempt_charge(subscription)
    return charge_result unless charge_result[:success]

    extend_subscription(subscription)
    @notifier.send_renewal_confirmation(subscription.user, subscription)

    { success: true, renewed_until: subscription.expires_at }
  end
end
