class Payment
  def charge(user, amount, card)
    puts "charging user: #{user.id}"
    p card
    puts "amount: #{amount}"

    validated = validate_card(card)
    unless validated
      puts 'card validation failed'
      return nil
    end

    puts 'card validated successfully'
    result = call_gateway(validated, amount)
    p result
    result
  end

  def refund(transaction_id, amount)
    puts "starting refund for transaction: #{transaction_id}"
    transaction = fetch_transaction(transaction_id)
    p transaction

    if transaction[:amount] < amount
      puts 'refund amount exceeds original'
      return { error: :exceeds_original }
    end

    puts "processing refund of #{amount}"
    result = call_refund_api(transaction, amount)
    p result
    result
  end

  def calculate_fee(amount, method)
    puts "fee calc input: #{amount} #{method}"
    fee =
      case method
      when :credit_card then amount * 0.029 + 0.30
      when :debit_card then amount * 0.015
      else amount * 0.035
      end
    puts "calculated fee: #{fee}"
    fee
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
