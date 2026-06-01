require 'logger'

class Payment
  def initialize
    @logger = Logger.new($stdout)
  end

  def charge(user, amount, card)
    validated = validate_card(card)
    unless validated
      @logger.warn("card validation failed user=#{user.id}")
      return nil
    end

    result = call_gateway(validated, amount)
    @logger.info("payment charged user=#{user.id} amount=#{amount}")
    result
  end

  def refund(transaction_id, amount)
    transaction = fetch_transaction(transaction_id)
    return { error: :not_found } unless transaction
    return { error: :exceeds_original } if transaction[:amount] < amount

    result = call_refund_api(transaction, amount)
    @logger.info("refund processed tx=#{transaction_id} amount=#{amount}")
    result
  end

  def calculate_fee(amount, method)
    case method
    when :credit_card then amount * 0.029 + 0.30
    when :debit_card then amount * 0.015
    when :bank_transfer then 0.25
    else amount * 0.035
    end
  end

  private

  def validate_card(card)
    card
  end

  def call_gateway(_card, _amount)
    { transaction_id: 'txn_123' }
  end

  def fetch_transaction(_id)
    { amount: 100.0 }
  end

  def call_refund_api(_transaction, _amount)
    { status: :refunded }
  end
end
