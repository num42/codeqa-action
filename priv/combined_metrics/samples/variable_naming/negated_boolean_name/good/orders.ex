defmodule Orders.Good do
  @moduledoc """
  Order fulfillment checks using positive boolean names.
  GOOD: is_paid, has_stock, is_shippable — positive names read as plain assertions.
  """

  @spec ready_to_ship?(map()) :: boolean()
  def ready_to_ship?(order) do
    is_paid = order.payment_state == :captured
    has_stock = Enum.all?(order.items, &(&1.available >= &1.quantity))
    is_within_window = order.placed_at >= cutoff()

    is_paid and has_stock and is_within_window
  end

  @spec can_cancel?(map()) :: boolean()
  def can_cancel?(order) do
    is_pending = order.state in [:placed, :confirmed]
    is_refundable = order.payment_state == :captured

    is_pending and is_refundable
  end

  @spec needs_review?(map()) :: boolean()
  def needs_review?(order) do
    is_high_value = order.total_cents > 100_000
    is_new_customer = order.customer.orders_count == 0

    is_high_value or is_new_customer
  end

  @spec apply_discount(map()) :: map()
  def apply_discount(order) do
    is_eligible = order.subtotal_cents >= 5_000
    has_coupon = order.coupon != nil

    cond do
      has_coupon -> %{order | discount_cents: coupon_value(order)}
      is_eligible -> %{order | discount_cents: div(order.subtotal_cents, 10)}
      true -> order
    end
  end

  defp cutoff, do: 0
  defp coupon_value(order), do: div(order.subtotal_cents, 5)
end
