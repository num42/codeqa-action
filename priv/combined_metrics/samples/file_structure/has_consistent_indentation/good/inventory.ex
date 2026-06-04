defmodule Warehouse.Inventory do
  @moduledoc """
  Tracks stock levels for warehouse items.
  """

  def reserve(stock, sku, qty) do
    case Map.get(stock, sku) do
      nil ->
        {:error, :unknown_sku}

      available when available >= qty ->
        {:ok, Map.put(stock, sku, available - qty)}

      _available ->
        {:error, :insufficient_stock}
    end
  end

  def restock(stock, sku, qty) do
    Map.update(stock, sku, qty, fn current -> current + qty end)
  end

  def low_stock(stock, threshold) do
    stock
    |> Enum.filter(fn {_sku, qty} -> qty < threshold end)
    |> Enum.map(fn {sku, _qty} -> sku end)
  end

  def total_units(stock) do
    stock
    |> Map.values()
    |> Enum.sum()
  end
end
