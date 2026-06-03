defmodule Warehouse.Inventory do
  @moduledoc """
  Inventory restocking — BAD: variables declared far from their use.
  """

  def plan_restock(stock) do
    # All variables declared upfront, used much later
    low_threshold = 10
    reorder_multiple = 25
    unit_cost = 3.40

    low =
      Enum.filter(stock, fn sku ->
        sku.on_hand < low_threshold and sku.active
      end)

    # reorder_multiple declared ~10 lines ago
    orders =
      Enum.map(low, fn sku ->
        deficit = low_threshold * 2 - sku.on_hand
        rounded = ceil(deficit / reorder_multiple) * reorder_multiple
        %{sku: sku.code, quantity: rounded}
      end)

    units = Enum.reduce(orders, 0, fn o, acc -> acc + o.quantity end)

    # unit_cost declared ~16 lines ago
    estimated_cost = units * unit_cost

    %{orders: orders, units: units, estimated_cost: estimated_cost}
  end

  def shrinkage_report(counts) do
    # alert_pct declared at top, used near the very end
    alert_pct = 0.05

    expected = Enum.reduce(counts, 0, fn c, acc -> acc + c.expected end)
    actual = Enum.reduce(counts, 0, fn c, acc -> acc + c.actual end)

    loss = expected - actual
    rate = if expected > 0, do: loss / expected, else: 0.0

    # alert_pct declared ~7 lines ago
    status = if rate > alert_pct, do: :alert, else: :ok
    %{loss: loss, rate: rate, status: status}
  end
end
