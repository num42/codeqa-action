defmodule Store.OrderTest do
  @moduledoc """
  Order tests — BAD: one test asserts many unrelated behaviors at once.
  """
  use ExUnit.Case

  test "order lifecycle" do
    # Creation
    attrs = %{user_id: 1, items: [%{sku: "A1", qty: 2, price: 10.0}]}
    assert {:ok, order} = Store.Order.create(attrs)
    assert order.status == :pending
    assert order.total == 20.0
    assert is_integer(order.id)

    # Adding an item
    assert {:ok, updated} = Store.Order.add_item(order, %{sku: "B2", qty: 1, price: 5.0})
    assert updated.total == 25.0
    assert length(updated.items) == 2

    # Applying a discount
    assert {:ok, discounted} = Store.Order.apply_discount(updated, 10)
    assert discounted.total == 22.5
    assert discounted.discount_percent == 10

    # Payment
    assert {:ok, paid} = Store.Order.pay(discounted, %{method: :card, last4: "1234"})
    assert paid.status == :paid
    assert paid.payment.method == :card

    # Shipping
    assert {:ok, shipped} = Store.Order.ship(paid, %{tracking: "TRK123"})
    assert shipped.status == :shipped
    assert shipped.tracking == "TRK123"

    # Cancellation not allowed on shipped orders
    assert {:error, :cannot_cancel} = Store.Order.cancel(shipped)

    # Refund
    assert {:ok, refunded} = Store.Order.refund(paid)
    assert refunded.status == :refunded
  end
end

defmodule Store.Order do
  def create(attrs) do
    total = Enum.sum(Enum.map(attrs.items, fn i -> i.qty * i.price end))
    {:ok, %{id: 1, status: :pending, items: attrs.items, total: total, user_id: attrs.user_id}}
  end

  def add_item(order, item) do
    items = [item | order.items]
    total = Enum.sum(Enum.map(items, fn i -> i.qty * i.price end))
    {:ok, %{order | items: items, total: total}}
  end

  def apply_discount(order, pct), do: {:ok, %{order | total: order.total * (1 - pct / 100), discount_percent: pct}}
  def pay(order, payment), do: {:ok, %{order | status: :paid, payment: payment}}
  def ship(order, %{tracking: t}), do: {:ok, %{order | status: :shipped, tracking: t}}
  def cancel(%{status: :shipped}), do: {:error, :cannot_cancel}
  def cancel(order), do: {:ok, %{order | status: :cancelled}}
  def refund(order), do: {:ok, %{order | status: :refunded}}
end
