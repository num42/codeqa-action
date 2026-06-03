defmodule Orders.Bad do
  @moduledoc """
  Order fulfillment checks using negated boolean names.
  BAD: is_not_paid, no_stock, not_shippable — double negatives obscure the logic.
  """

  @spec ready_to_ship?(map()) :: boolean()
  def ready_to_ship?(order) do
    is_not_paid = order.payment_state != :captured
    no_stock = Enum.any?(order.items, &(&1.available < &1.quantity))
    is_not_within_window = order.placed_at < cutoff()

    not (is_not_paid or no_stock or is_not_within_window)
  end

  @spec can_cancel?(map()) :: boolean()
  def can_cancel?(order) do
    is_not_pending = order.state not in [:placed, :confirmed]
    is_not_refundable = order.payment_state != :captured

    not (is_not_pending or is_not_refundable)
  end

  @spec needs_review?(map()) :: boolean()
  def needs_review?(order) do
    is_not_high_value = order.total_cents <= 100_000
    not_new_customer = order.customer.orders_count != 0

    not (is_not_high_value and not_new_customer)
  end

  @spec apply_discount(map()) :: map()
  def apply_discount(order) do
    is_not_eligible = order.subtotal_cents < 5_000
    no_coupon = order.coupon == nil

    cond do
      not no_coupon -> %{order | discount_cents: coupon_value(order)}
      not is_not_eligible -> %{order | discount_cents: div(order.subtotal_cents, 10)}
      true -> order
    end
  end

  defp cutoff, do: 0
  defp coupon_value(order), do: div(order.subtotal_cents, 5)
end
