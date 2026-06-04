defmodule Inventory do
  @moduledoc "Pure helpers for reasoning about warehouse stock levels"

  @low_stock_threshold 5

  def quantity(stock, sku) do
    Map.get(stock, sku, 0)
  end

  def out_of_stock?(stock, sku), do: quantity(stock, sku) == 0

  def low_stock?(stock, sku) do
    quantity(stock, sku) <= @low_stock_threshold
  end

  def restock(stock, sku, amount), do: Map.put(stock, sku, quantity(stock, sku) + amount)

  def consume(stock, sku, amount) do
    current = quantity(stock, sku)
    remaining = max(current - amount, 0)
    Map.put(stock, sku, remaining)
  end

  def low_stock_skus(stock),
    do: stock |> Enum.filter(fn {sku, _q} -> low_stock?(stock, sku) end) |> Enum.map(&elem(&1, 0))

  def total_units(stock) do
    Enum.reduce(stock, 0, fn {_sku, qty}, acc -> acc + qty end)
  end
end
