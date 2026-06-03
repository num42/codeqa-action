defmodule Pricing.Bad do
  @moduledoc """
  Price resolution — BAD: values initialized to nil then assigned in branches.
  """

  def quote(cart, customer) do
    base = nil
    discount = nil
    shipping = nil

    base = subtotal(cart)

    if customer.tier == :gold do
      discount = div(base, 10)
    end

    if discount == nil do
      discount = 0
    end

    if customer.tier == :gold do
      shipping = 0
    else
      shipping = 499
    end

    %{base: base, discount: discount, shipping: shipping, total: base - discount + shipping}
  end

  def discount_for(customer, base) do
    discount = nil

    if customer.tier == :gold do
      discount = div(base, 10)
    end

    if customer.tier == :silver do
      discount = div(base, 20)
    end

    if discount == nil do
      discount = 0
    end

    discount
  end

  def coupon_value(coupon, base) do
    value = nil

    if coupon != nil do
      value = div(base * coupon.value, 100)
    end

    if value == nil do
      value = 0
    end

    value
  end

  defp subtotal(cart), do: Enum.reduce(cart, 0, &(&1.price * &1.qty + &2))
end
