# Pricing and discount calculator with single-letter variable names.
# BAD: function params and local vars named x, y, z, a, b, n, m lose all meaning.

class CalculatorBad
  def apply_discount(x, y)
    z = x * (1 - y / 100.0)
    z.round(2)
  end

  def calculate_total(a, b)
    n = a.sum
    m = n * (1 + b / 100.0)
    m.round(2)
  end

  def tiered_price(x, y)
    y.reduce(x) do |acc, (a, b)|
      acc > a ? acc * (1 - b / 100.0) : acc
    end
  end

  def split_payment(a, n)
    b = (a / n).round(2)
    m = (a - b * (n - 1)).round(2)
    Array.new(n - 1, b) + [m]
  end

  def compound_discount(x, y)
    z = y.reduce(x) { |b, a| b * (1 - a / 100.0) }
    z.round(2)
  end

  def price_with_tax(x, y, z)
    a = x * y
    b = a * z / 100.0
    {
      subtotal: a.round(2),
      tax: b.round(2),
      total: (a + b).round(2)
    }
  end

  def bulk_pricing(x, n, m)
    if n >= m
      (x * 0.75).round(2)
    elsif n >= m / 2
      (x * 0.9).round(2)
    else
      x
    end
  end

  def margin(x, y)
    z = (x - y) / x.to_f * 100
    z.round(2)
  end

  def currency_convert(a, b, c)
    n = a * b
    m = n - n * c / 100.0
    m.round(2)
  end

  def installment_schedule(x, n, y)
    a = x * (1 + y / 100.0)
    b = (a / n).round(2)

    (1..n).map do |m|
      amount = m < n ? b : (a - b * (n - 1)).round(2)
      { installment: m, amount: amount }
    end
  end
end
