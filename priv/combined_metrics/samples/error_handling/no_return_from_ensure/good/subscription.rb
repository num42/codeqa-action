class SubscriptionActivator
  def initialize(billing_client, notifier, logger)
    @billing_client = billing_client
    @notifier = notifier
    @logger = logger
  end

  def activate(subscription)
    result = nil

    begin
      @billing_client.authorize(subscription.payment_method_id, subscription.plan.monthly_price)
      subscription.update!(status: :active, activated_at: Time.current)
      @notifier.send_welcome_email(subscription.user)
      result = { success: true, subscription: subscription }
    rescue BillingClient::AuthorizationError => e
      @logger.warn("Authorization failed for subscription #{subscription.id}: #{e.message}")
      result = { success: false, error: :payment_authorization_failed }
    rescue StandardError => e
      @logger.error("Unexpected error activating subscription #{subscription.id}: #{e.message}")
      raise
    ensure
      @logger.info("Activation attempt completed for subscription #{subscription.id}")
      cleanup_pending_state(subscription)
    end

    result
  end

  def cancel(subscription, reason:)
    begin
      subscription.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: reason)
      @billing_client.cancel_recurring(subscription.billing_id)
      @notifier.send_cancellation_confirmation(subscription.user)
    rescue BillingClient::NotFoundError => e
      @logger.warn("Billing record not found during cancel #{subscription.id}: #{e.message}")
    ensure
      release_subscription_seats(subscription)
      @logger.info("Cancellation cleanup done for #{subscription.id}")
    end
  end

  private

  def cleanup_pending_state(subscription)
    subscription.update_column(:pending_activation, false) if subscription.pending_activation?
  end

  def release_subscription_seats(subscription)
    subscription.team_seats.update_all(active: false)
  end
end
