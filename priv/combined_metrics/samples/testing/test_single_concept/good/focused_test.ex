defmodule Store.OrderTest do
  @moduledoc """
  Order tests — GOOD: each test covers exactly one behavior.
  """
  use ExUnit.Case

  defp pending_order do
    attrs = %{user_id: 1, items: [%{sku: "A1", qty: 2, price: 10.0}]}
    {:ok, order} = Store.Order.create(attrs)
    order
  end

  describe "create/1" do
    test "sets status to :pending" do
      order = pending_order()
      assert order.status == :pending
    end

    test "calculates total from line items" do
      order = pending_order()
      assert order.total == 20.0
    end

    test "assigns a numeric id" do
      order = pending_order()
      assert is_integer(order.id)
    end
  end

  describe "add_item/2" do
    test "increases total by the new item's value" do
      order = pending_order()
      assert {:ok, updated} = Store.Order.add_item(order, %{sku: "B2", qty: 1, price: 5.0})
      assert updated.total == 25.0
    end

    test "appends the item to the items list" do
      order = pending_order()
      assert {:ok, updated} = Store.Order.add_item(order, %{sku: "B2", qty: 1, price: 5.0})
      assert length(updated.items) == 2
    end
  end

  describe "apply_discount/2" do
    test "reduces total by the given percentage" do
      order = pending_order()
      assert {:ok, discounted} = Store.Order.apply_discount(order, 10)
      assert discounted.total == 18.0
    end

    test "stores the discount percentage on the order" do
      order = pending_order()
      assert {:ok, discounted} = Store.Order.apply_discount(order, 10)
      assert discounted.discount_percent == 10
    end
  end

  describe "pay/2" do
    test "sets status to :paid" do
      order = pending_order()
      assert {:ok, paid} = Store.Order.pay(order, %{method: :card, last4: "1234"})
      assert paid.status == :paid
    end
  end

  describe "cancel/1" do
    test "returns {:error, :cannot_cancel} for shipped orders" do
      order = pending_order()
      {:ok, paid} = Store.Order.pay(order, %{method: :card, last4: "1234"})
      {:ok, shipped} = Store.Order.ship(paid, %{tracking: "TRK123"})
      assert Store.Order.cancel(shipped) == {:error, :cannot_cancel}
    end

    test "sets status to :cancelled for pending orders" do
      order = pending_order()
      assert {:ok, cancelled} = Store.Order.cancel(order)
      assert cancelled.status == :cancelled
    end
  end
end

defmodule Store.Order do
  def create(attrs) do
    total = Enum.sum(Enum.map(attrs.items, fn i -> i.qty * i.price end))
    {:ok, %{id: 1, status: :pending, items: attrs.items, total: total, user_id: attrs.user_id}}
  end

  def add_item(order, item) do
    items = [item | order.items]
    {:ok, %{order | items: items, total: Enum.sum(Enum.map(items, fn i -> i.qty * i.price end))}}
  end

  def apply_discount(order, pct), do: {:ok, %{order | total: order.total * (1 - pct / 100), discount_percent: pct}}
  def pay(order, payment), do: {:ok, %{order | status: :paid, payment: payment}}
  def ship(order, %{tracking: t}), do: {:ok, %{order | status: :shipped, tracking: t}}
  def cancel(%{status: :shipped}), do: {:error, :cannot_cancel}
  def cancel(order), do: {:ok, %{order | status: :cancelled}}
  def refund(order), do: {:ok, %{order | status: :refunded}}
end
