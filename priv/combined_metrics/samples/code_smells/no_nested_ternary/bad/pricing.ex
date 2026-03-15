defmodule Pricing do
  @moduledoc "Calculates prices and discounts for products"

  def final_price(product, user, coupon) do
    base =
      if product.on_sale do
        if product.sale_price > 0 do
          product.sale_price
        else
          product.price * 0.9
        end
      else
        product.price
      end

    with_membership =
      if user.member do
        if user.tier == :gold do
          if base > 100 do
            base * 0.75
          else
            base * 0.85
          end
        else
          base * 0.9
        end
      else
        base
      end

    if coupon != nil do
      if coupon.type == :percent do
        if coupon.value > 50 do
          with_membership * 0.5
        else
          with_membership * (1 - coupon.value / 100)
        end
      else
        if with_membership - coupon.value > 0 do
          with_membership - coupon.value
        else
          0
        end
      end
    else
      with_membership
    end
  end

  def shipping_cost(order, user) do
    if order.total > 50 do
      if user.member do
        0
      else
        if order.express do
          9.99
        else
          4.99
        end
      end
    else
      if user.member do
        if order.express do
          5.99
        else
          2.99
        end
      else
        if order.express do
          14.99
        else
          7.99
        end
      end
    end
  end

  def tax_rate(country, region, product_type) do
    if country == "US" do
      if region == "CA" do
        if product_type == :food do
          0.0
        else
          0.0725
        end
      else
        if product_type == :food do
          0.0
        else
          0.05
        end
      end
    else
      if country == "DE" do
        if product_type == :food do
          0.07
        else
          0.19
        end
      else
        0.0
      end
    end
  end
end
