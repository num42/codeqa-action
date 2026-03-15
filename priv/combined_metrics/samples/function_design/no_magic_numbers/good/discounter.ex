defmodule Discounter do
  @vip_discount 0.20
  @member_discount 0.10
  @new_user_discount 0.15

  @bulk_tier_large_threshold 100
  @bulk_tier_medium_threshold 50
  @bulk_tier_small_threshold 10
  @bulk_tier_large_rate 0.70
  @bulk_tier_medium_rate 0.80
  @bulk_tier_small_rate 0.90

  @coupon_save5_amount 500
  @coupon_save10_amount 1000
  @coupon_half_rate 0.50

  @seasonal_months [11, 12]
  @seasonal_rate 0.85

  @minimum_order_threshold 10_000
  @minimum_order_rate 0.95

  def apply_discount(price, :vip), do: price * (1 - @vip_discount)
  def apply_discount(price, :member), do: price * (1 - @member_discount)
  def apply_discount(price, :new_user), do: price * (1 - @new_user_discount)
  def apply_discount(price, _), do: price

  def calculate_bulk_discount(price, quantity) do
    cond do
      quantity >= @bulk_tier_large_threshold -> price * @bulk_tier_large_rate
      quantity >= @bulk_tier_medium_threshold -> price * @bulk_tier_medium_rate
      quantity >= @bulk_tier_small_threshold -> price * @bulk_tier_small_rate
      true -> price
    end
  end

  def apply_coupon(price, "SAVE5"), do: max(price - @coupon_save5_amount, 0)
  def apply_coupon(price, "SAVE10"), do: max(price - @coupon_save10_amount, 0)
  def apply_coupon(price, "HALF"), do: price * @coupon_half_rate
  def apply_coupon(price, _), do: price

  def seasonal_discount(price, month) do
    if month in @seasonal_months, do: price * @seasonal_rate, else: price
  end

  def calculate_tax(price, :us_ca), do: price * 1.0725
  def calculate_tax(price, :us_ny), do: price * 1.08875
  def calculate_tax(price, :uk), do: price * 1.20
  def calculate_tax(price, _), do: price

  def minimum_order_discount(price, total) do
    if total >= @minimum_order_threshold, do: price * @minimum_order_rate, else: price
  end
end
