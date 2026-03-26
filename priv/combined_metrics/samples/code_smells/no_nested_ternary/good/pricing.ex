defmodule Pricing do
  @moduledoc "Calculates prices and discounts for products"

  def final_price(product, user, coupon) do
    product
    |> base_price()
    |> apply_membership(user)
    |> apply_coupon(coupon)
  end

  defp base_price(%{on_sale: true, sale_price: sale}) when sale > 0, do: sale
  defp base_price(%{on_sale: true, price: price}), do: price * 0.9
  defp base_price(%{price: price}), do: price

  defp apply_membership(price, %{member: true, tier: :gold}) when price > 100, do: price * 0.75
  defp apply_membership(price, %{member: true, tier: :gold}), do: price * 0.85
  defp apply_membership(price, %{member: true}), do: price * 0.9
  defp apply_membership(price, _user), do: price

  defp apply_coupon(price, nil), do: price

  defp apply_coupon(price, %{type: :percent, value: value}) when value > 50 do
    price * 0.5
  end

  defp apply_coupon(price, %{type: :percent, value: value}) do
    price * (1 - value / 100)
  end

  defp apply_coupon(price, %{type: :fixed, value: value}) do
    max(price - value, 0)
  end

  def shipping_cost(order, user) do
    shipping_rate(order.total, user.member, order.express)
  end

  defp shipping_rate(total, _member, _express) when total > 50, do: 0
  defp shipping_rate(_total, true, true), do: 5.99
  defp shipping_rate(_total, true, false), do: 2.99
  defp shipping_rate(_total, false, true), do: 14.99
  defp shipping_rate(_total, false, false), do: 7.99

  def tax_rate(country, region, product_type) do
    tax_for(country, region, product_type)
  end

  defp tax_for("US", _region, :food), do: 0.0
  defp tax_for("US", "CA", _type), do: 0.0725
  defp tax_for("US", _region, _type), do: 0.05
  defp tax_for("DE", :food, _type), do: 0.07
  defp tax_for("DE", _region, _type), do: 0.19
  defp tax_for(_country, _region, _type), do: 0.0
end
