defmodule Inventory.Bad do
  @moduledoc """
  Warehouse stock handling with type suffixes in variable names.
  BAD: variables include redundant type suffixes like _list, _keyword, _integer, _string.
  """

  @spec restock(map(), keyword()) :: map()
  def restock(warehouse_map, opts_keyword) do
    item_list = Map.get(warehouse_map, :items, [])
    threshold_integer = Keyword.get(opts_keyword, :threshold, 10)
    supplier_string = Keyword.get(opts_keyword, :supplier, "default")

    low_list = Enum.filter(item_list, fn item -> item.quantity < threshold_integer end)
    name_list = Enum.map(low_list, & &1.name)
    count_integer = length(low_list)

    order_list =
      Enum.map(low_list, fn item ->
        %{sku: item.sku, amount: threshold_integer - item.quantity, from: supplier_string}
      end)

    %{
      warehouse: warehouse_map.id,
      low_stock: name_list,
      reorder_count: count_integer,
      orders: order_list
    }
  end

  @spec valuation(list()) :: integer()
  def valuation(item_list) do
    Enum.reduce(item_list, 0, fn item, total_integer ->
      total_integer + item.quantity * item.unit_price
    end)
  end

  @spec group_by_category(list()) :: map()
  def group_by_category(item_list) do
    Enum.group_by(item_list, & &1.category, & &1.sku)
  end
end
