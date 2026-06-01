defmodule Discounter do
  def apply_discount(price, :vip) do
    price * (1 - 0.20)
  end

  def apply_discount(price, :member) do
    price * (1 - 0.10)
  end

  def apply_discount(price, :new_user) do
    price * (1 - 0.15)
  end

  def apply_discount(price, _), do: price

  def calculate_bulk_discount(price, quantity) do
    cond do
      quantity >= 100 -> price * 0.70
      quantity >= 50 -> price * 0.80
      quantity >= 10 -> price * 0.90
      true -> price
    end
  end

  def apply_coupon(price, coupon_code) do
    case coupon_code do
      "SAVE5" -> max(price - 500, 0)
      "SAVE10" -> max(price - 1000, 0)
      "HALF" -> price * 0.50
      _ -> price
    end
  end

  def seasonal_discount(price, month) do
    if month in [11, 12] do
      price * 0.85
    else
      price
    end
  end

  def calculate_tax(price, region) do
    case region do
      :us_ca -> price * 1.0725
      :us_ny -> price * 1.08875
      :uk -> price * 1.20
      _ -> price
    end
  end

  def minimum_order_discount(price, total) do
    if total >= 10_000 do
      price * 0.95
    else
      price
    end
  end
end
