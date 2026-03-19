defmodule MyApp.Inventory do
  @moduledoc """
  Inventory calculations. Pure module with stateless functions —
  no GenServer or Agent needed because there is no mutable state
  or concurrency concern. The "state" is just data passed around.
  """

  alias MyApp.Inventory.{Product, StockLevel}

  @doc """
  Checks whether a product has enough stock for the requested quantity.
  Pure function — no process needed.
  """
  @spec sufficient_stock?(Product.t(), pos_integer()) :: boolean()
  def sufficient_stock?(%Product{stock: stock}, quantity), do: stock >= quantity

  @doc """
  Computes a reservation summary for a list of items.
  Pure transformation — no process needed.
  """
  @spec compute_reservation([{Product.t(), pos_integer()}]) :: map()
  def compute_reservation(items) when is_list(items) do
    items
    |> Enum.reduce(%{available: [], unavailable: []}, fn {product, qty}, acc ->
      if sufficient_stock?(product, qty) do
        Map.update!(acc, :available, &[{product.id, qty} | &1])
      else
        Map.update!(acc, :unavailable, &[{product.id, qty} | &1])
      end
    end)
  end

  @doc """
  Calculates the reorder point for a product based on lead time and daily usage.
  Pure computation — no process involved.
  """
  @spec reorder_point(float(), pos_integer()) :: integer()
  def reorder_point(daily_usage, lead_time_days) when daily_usage >= 0 do
    ceil(daily_usage * lead_time_days * 1.2)
  end

  @doc """
  Groups stock levels by warehouse.
  Pure data transformation.
  """
  @spec group_by_warehouse([StockLevel.t()]) :: map()
  def group_by_warehouse(levels) when is_list(levels) do
    Enum.group_by(levels, & &1.warehouse_id)
  end

  @doc """
  Merges two stock level maps, summing quantities for shared keys.
  """
  @spec merge_stock(map(), map()) :: map()
  def merge_stock(stock_a, stock_b) do
    Map.merge(stock_a, stock_b, fn _warehouse, qty_a, qty_b -> qty_a + qty_b end)
  end
end
