class PaymentProcessor
  def initialize(gateway, logger)
    @gateway = gateway
    @logger = logger
  end

  def charge(order, card_token)
    amount_cents = (order.total * 100).to_i

    begin
      response = @gateway.charge(amount_cents, card_token, order_id: order.id)
      record_transaction(order, response.transaction_id)
      { success: true, transaction_id: response.transaction_id }
    rescue PaymentGateway::CardDeclinedError => e
      @logger.warn("Card declined for order #{order.id}: #{e.message}")
      { success: false, error: :card_declined, message: e.message }
    rescue PaymentGateway::NetworkError => e
      @logger.error("Gateway network error for order #{order.id}: #{e.message}")
      { success: false, error: :network_error, message: "Payment service unavailable" }
    rescue PaymentGateway::InvalidAmountError => e
      @logger.error("Invalid amount #{amount_cents} for order #{order.id}: #{e.message}")
      raise ArgumentError, "Order total is invalid: #{order.total}"
    end
  end

  def refund(transaction_id, amount_cents)
    begin
      response = @gateway.refund(transaction_id, amount_cents)
      @logger.info("Refund issued: #{response.refund_id} for transaction #{transaction_id}")
      { success: true, refund_id: response.refund_id }
    rescue PaymentGateway::TransactionNotFoundError => e
      @logger.error("Refund failed — transaction not found: #{transaction_id} — #{e.message}")
      { success: false, error: :transaction_not_found }
    rescue PaymentGateway::RefundError => e
      @logger.error("Refund failed for transaction #{transaction_id}: #{e.message}")
      { success: false, error: :refund_failed, message: e.message }
    end
  end

  private

  def record_transaction(order, transaction_id)
    order.update!(
      payment_status: :paid,
      transaction_id: transaction_id,
      paid_at: Time.current
    )
  end
end
