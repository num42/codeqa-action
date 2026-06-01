# Pricing and discount calculator with descriptive variable names.
# GOOD: params and locals named price, discount, quantity, amount make intent clear.

class CalculatorGood
  def apply_discount(price, discount_percent)
    discounted = price * (1 - discount_percent / 100.0)
    discounted.round(2)
  end

  def calculate_total(amounts, tax_rate)
    subtotal = amounts.sum
    total = subtotal * (1 + tax_rate / 100.0)
    total.round(2)
  end

  def tiered_price(price, tiers)
    tiers.reduce(price) do |current_price, (threshold, discount_percent)|
      current_price > threshold ? current_price * (1 - discount_percent / 100.0) : current_price
    end
  end

  def split_payment(amount, count)
    installment = (amount / count).round(2)
    last_installment = (amount - installment * (count - 1)).round(2)
    Array.new(count - 1, installment) + [last_installment]
  end

  def compound_discount(price, discount_percents)
    final_price = discount_percents.reduce(price) do |current_price, discount_percent|
      current_price * (1 - discount_percent / 100.0)
    end
    final_price.round(2)
  end

  def price_with_tax(unit_price, quantity, tax_rate)
    subtotal = unit_price * quantity
    tax = subtotal * tax_rate / 100.0
    {
      subtotal: subtotal.round(2),
      tax: tax.round(2),
      total: (subtotal + tax).round(2)
    }
  end

  def bulk_pricing(price, quantity, bulk_threshold)
    if quantity >= bulk_threshold
      (price * 0.75).round(2)
    elsif quantity >= bulk_threshold / 2
      (price * 0.9).round(2)
    else
      price
    end
  end

  def margin(selling_price, cost)
    margin_percent = (selling_price - cost) / selling_price.to_f * 100
    margin_percent.round(2)
  end

  def currency_convert(amount, exchange_rate, conversion_fee)
    converted = amount * exchange_rate
    after_fee = converted - converted * conversion_fee / 100.0
    after_fee.round(2)
  end

  def installment_schedule(principal, count, annual_rate)
    total_amount = principal * (1 + annual_rate / 100.0)
    installment = (total_amount / count).round(2)

    (1..count).map do |index|
      payment = index < count ? installment : (total_amount - installment * (count - 1)).round(2)
      { installment: index, amount: payment }
    end
  end
end
