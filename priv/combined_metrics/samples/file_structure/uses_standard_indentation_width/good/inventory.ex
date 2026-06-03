defmodule Inventory do
  @moduledoc """
  Tracks stock levels for warehouse items.
  """

  def add_stock(items, sku, quantity) do
    Map.update(items, sku, quantity, fn current ->
      current + quantity
    end)
  end

  def remove_stock(items, sku, quantity) do
    case Map.fetch(items, sku) do
      {:ok, current} when current >= quantity ->
        {:ok, Map.put(items, sku, current - quantity)}

      {:ok, _current} ->
        {:error, :insufficient_stock}

      :error ->
        {:error, :unknown_sku}
    end
  end

  def total_units(items) do
    Enum.reduce(items, 0, fn {_sku, quantity}, acc ->
      acc + quantity
    end)
  end

  def low_stock(items, threshold) do
    items
    |> Enum.filter(fn {_sku, quantity} -> quantity < threshold end)
    |> Enum.map(fn {sku, _quantity} -> sku end)
  end
end
