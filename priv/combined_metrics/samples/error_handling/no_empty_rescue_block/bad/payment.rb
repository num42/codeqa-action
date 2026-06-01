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
    rescue PaymentGateway::CardDeclinedError
      # TODO: handle this
    rescue PaymentGateway::NetworkError
    rescue PaymentGateway::InvalidAmountError
    end
  end

  def refund(transaction_id, amount_cents)
    begin
      response = @gateway.refund(transaction_id, amount_cents)
      { success: true, refund_id: response.refund_id }
    rescue PaymentGateway::TransactionNotFoundError
    rescue PaymentGateway::RefundError
    end
  end

  private

  def record_transaction(order, transaction_id)
    begin
      order.update!(
        payment_status: :paid,
        transaction_id: transaction_id,
        paid_at: Time.current
      )
    rescue
    end
  end
end
