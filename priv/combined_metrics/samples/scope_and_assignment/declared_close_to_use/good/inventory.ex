defmodule Warehouse.Inventory do
  @moduledoc """
  Inventory restocking — GOOD: variables declared immediately before use.
  """

  def plan_restock(stock) do
    low_threshold = 10

    low =
      Enum.filter(stock, fn sku ->
        sku.on_hand < low_threshold and sku.active
      end)

    reorder_multiple = 25

    orders =
      Enum.map(low, fn sku ->
        deficit = low_threshold * 2 - sku.on_hand
        rounded = ceil(deficit / reorder_multiple) * reorder_multiple
        %{sku: sku.code, quantity: rounded}
      end)

    units = Enum.reduce(orders, 0, fn o, acc -> acc + o.quantity end)
    unit_cost = 3.40
    estimated_cost = units * unit_cost

    %{orders: orders, units: units, estimated_cost: estimated_cost}
  end

  def shrinkage_report(counts) do
    expected = Enum.reduce(counts, 0, fn c, acc -> acc + c.expected end)
    actual = Enum.reduce(counts, 0, fn c, acc -> acc + c.actual end)

    loss = expected - actual
    alert_pct = 0.05
    rate = if expected > 0, do: loss / expected, else: 0.0

    status = if rate > alert_pct, do: :alert, else: :ok
    %{loss: loss, rate: rate, status: status}
  end
end
