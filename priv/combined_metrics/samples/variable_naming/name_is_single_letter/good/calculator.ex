defmodule Calculator.Good do
  @moduledoc """
  Pricing and discount calculator with descriptive variable names.
  GOOD: params and locals named price, discount, quantity, amount make intent clear.
  """

  @spec apply_discount(number(), number()) :: number()
  def apply_discount(price, discount_percent) do
    discounted = price * (1 - discount_percent / 100)
    Float.round(discounted, 2)
  end

  @spec calculate_total(list(), number()) :: number()
  def calculate_total(amounts, tax_rate) do
    subtotal = Enum.reduce(amounts, 0, fn amount, acc -> acc + amount end)
    total = subtotal * (1 + tax_rate / 100)
    Float.round(total, 2)
  end

  @spec tiered_price(number(), list()) :: number()
  def tiered_price(price, tiers) do
    Enum.reduce_while(tiers, price, fn {threshold, discount_percent}, current_price ->
      if current_price > threshold do
        {:cont, current_price * (1 - discount_percent / 100)}
      else
        {:halt, current_price}
      end
    end)
  end

  @spec split_payment(number(), integer()) :: list(number())
  def split_payment(amount, count) do
    installment = Float.round(amount / count, 2)
    last_installment = amount - installment * (count - 1)
    List.duplicate(installment, count - 1) ++ [Float.round(last_installment, 2)]
  end

  @spec compound_discount(number(), list()) :: number()
  def compound_discount(price, discount_percents) do
    Enum.reduce(discount_percents, price, fn discount_percent, current_price ->
      current_price * (1 - discount_percent / 100)
    end)
    |> Float.round(2)
  end

  @spec price_with_tax(number(), number(), number()) :: map()
  def price_with_tax(unit_price, quantity, tax_rate) do
    subtotal = unit_price * quantity
    tax = subtotal * tax_rate / 100
    %{
      subtotal: Float.round(subtotal, 2),
      tax: Float.round(tax, 2),
      total: Float.round(subtotal + tax, 2)
    }
  end

  @spec bulk_pricing(number(), integer(), integer()) :: number()
  def bulk_pricing(price, quantity, bulk_threshold) do
    cond do
      quantity >= bulk_threshold -> price * 0.75
      quantity >= div(bulk_threshold, 2) -> price * 0.9
      true -> price
    end
    |> Float.round(2)
  end

  @spec margin(number(), number()) :: number()
  def margin(selling_price, cost) do
    margin_percent = (selling_price - cost) / selling_price * 100
    Float.round(margin_percent, 2)
  end
end
