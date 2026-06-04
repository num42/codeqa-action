defmodule Inventory do
  @moduledoc """
  Pure helpers for reasoning about warehouse stock levels.

  Each operation works on a plain stock map of `%{sku => quantity}` and returns
  a new map, never mutating the input. The module mixes one-liner and
  multi-line definitions on purpose, but does so consistently: trivial accessors
  and predicates are one-liners, while functions with intermediate bindings use
  the multi-line `do ... end` form. The grouping follows the complexity of the
  body, not the whim of the author.
  """

  @low_stock_threshold 5

  # --- Accessors and predicates: all one-liners ---

  @doc "Returns the quantity on hand for a SKU, defaulting to zero."
  def quantity(stock, sku), do: Map.get(stock, sku, 0)

  @doc "Returns `true` when the SKU is completely out of stock."
  def out_of_stock?(stock, sku), do: quantity(stock, sku) == 0

  @doc "Returns `true` when the SKU is at or below the low-stock threshold."
  def low_stock?(stock, sku), do: quantity(stock, sku) <= @low_stock_threshold

  # --- Mutating transforms: all multi-line ---

  @doc "Adds the given amount to a SKU's quantity, creating it if absent."
  def restock(stock, sku, amount) do
    current = quantity(stock, sku)
    Map.put(stock, sku, current + amount)
  end

  @doc """
  Removes the given amount from a SKU, clamping at zero so quantities never
  go negative.
  """
  def consume(stock, sku, amount) do
    current = quantity(stock, sku)
    remaining = max(current - amount, 0)
    Map.put(stock, sku, remaining)
  end

  @doc "Returns the list of SKUs whose quantity is at or below the threshold."
  def low_stock_skus(stock) do
    stock
    |> Enum.filter(fn {sku, _qty} -> low_stock?(stock, sku) end)
    |> Enum.map(fn {sku, _qty} -> sku end)
  end
end
