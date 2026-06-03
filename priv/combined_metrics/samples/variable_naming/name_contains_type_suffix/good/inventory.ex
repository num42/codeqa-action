defmodule Inventory.Good do
  @moduledoc """
  Warehouse stock handling without type suffixes in variable names.
  GOOD: variable names express what the data is, not what type it has.
  """

  @spec restock(map(), keyword()) :: map()
  def restock(warehouse, opts) do
    items = Map.get(warehouse, :items, [])
    threshold = Keyword.get(opts, :threshold, 10)
    supplier = Keyword.get(opts, :supplier, "default")

    low = Enum.filter(items, fn item -> item.quantity < threshold end)
    names = Enum.map(low, & &1.name)
    count = length(low)

    orders =
      Enum.map(low, fn item ->
        %{sku: item.sku, amount: threshold - item.quantity, from: supplier}
      end)

    %{
      warehouse: warehouse.id,
      low_stock: names,
      reorder_count: count,
      orders: orders
    }
  end

  @spec valuation(list()) :: integer()
  def valuation(items) do
    Enum.reduce(items, 0, fn item, total ->
      total + item.quantity * item.unit_price
    end)
  end

  @spec group_by_category(list()) :: map()
  def group_by_category(items) do
    Enum.group_by(items, & &1.category, & &1.sku)
  end
end
