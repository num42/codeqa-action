defmodule Shop.CartRules do
  @moduledoc """
  Shopping cart rule evaluation — GOOD: eligibility booleans assigned directly
  from comparisons and membership checks.
  """

  def evaluate(cart) do
    has_items = cart.item_count > 0
    free_shipping = cart.subtotal >= 5000
    needs_minimum = cart.subtotal < 1000
    coupon_applicable = cart.coupon != nil and cart.subtotal >= cart.coupon.threshold

    %{
      checkout_enabled: has_items and not needs_minimum,
      free_shipping: free_shipping,
      coupon_applicable: coupon_applicable
    }
  end

  def item_flags(item) do
    in_stock = item.stock > 0
    backorderable = item.stock == 0 and item.allow_backorder
    on_sale = item.sale_price != nil and item.sale_price < item.price
    bulk_eligible = item.quantity >= item.bulk_threshold

    %{
      in_stock: in_stock,
      backorderable: backorderable,
      on_sale: on_sale,
      bulk_eligible: bulk_eligible
    }
  end

  def gift_eligible?(cart, customer) do
    spending_met = cart.subtotal >= 10_000
    member = customer.tier in [:gold, :platinum]
    first_order = customer.order_count == 0

    spending_met and (member or first_order)
  end
end
