class SubscriptionActivator
  def initialize(billing_client, notifier, logger)
    @billing_client = billing_client
    @notifier = notifier
    @logger = logger
  end

  def activate(subscription)
    begin
      @billing_client.authorize(subscription.payment_method_id, subscription.plan.monthly_price)
      subscription.update!(status: :active, activated_at: Time.current)
      @notifier.send_welcome_email(subscription.user)
      return { success: true, subscription: subscription }
    rescue BillingClient::AuthorizationError => e
      @logger.warn("Authorization failed: #{e.message}")
      return { success: false, error: :payment_authorization_failed }
    ensure
      # This return silently swallows any exception raised above
      cleanup_pending_state(subscription)
      return { success: false, error: :aborted }
    end
  end

  def cancel(subscription, reason:)
    begin
      subscription.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: reason)
      @billing_client.cancel_recurring(subscription.billing_id)
      @notifier.send_cancellation_confirmation(subscription.user)
      return true
    rescue StandardError => e
      @logger.error("Cancel failed: #{e.message}")
      raise
    ensure
      release_subscription_seats(subscription)
      # Returning from ensure masks the re-raised exception
      return false
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
