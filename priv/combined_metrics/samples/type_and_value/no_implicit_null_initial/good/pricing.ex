defmodule Pricing.Good do
  @moduledoc """
  Price resolution — GOOD: each value comes straight from an expression.
  """

  def quote(cart, customer) do
    base = subtotal(cart)
    discount = discount_for(customer, base)
    shipping = shipping_for(cart, customer)

    %{base: base, discount: discount, shipping: shipping, total: base - discount + shipping}
  end

  def discount_for(customer, base) do
    case customer.tier do
      :gold -> div(base, 10)
      :silver -> div(base, 20)
      _ -> 0
    end
  end

  def shipping_for(cart, customer) do
    cond do
      customer.tier == :gold -> 0
      subtotal(cart) >= 5_000 -> 0
      true -> 499
    end
  end

  def coupon_value(nil, _base), do: 0
  def coupon_value(%{type: :percent, value: value}, base), do: div(base * value, 100)
  def coupon_value(%{type: :flat, value: value}, _base), do: value

  defp subtotal(cart), do: Enum.reduce(cart, 0, &(&1.price * &1.qty + &2))
end
