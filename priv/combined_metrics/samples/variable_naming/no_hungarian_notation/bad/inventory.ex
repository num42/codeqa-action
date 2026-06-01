defmodule Inventory.Bad do
  @moduledoc """
  Inventory management using Hungarian notation prefixes.
  BAD: str_name, b_active, n_count, arr_items, int_age, obj_user, fn_callback, d_price.
  """

  @spec add_item(map()) :: {:ok, map()} | {:error, String.t()}
  def add_item(obj_item) do
    str_name = obj_item.name
    str_sku = obj_item.sku
    n_quantity = obj_item.quantity
    d_price = obj_item.price
    b_active = Map.get(obj_item, :active, true)

    if str_name == "" or is_nil(str_name) do
      {:error, "Name is required"}
    else
      {:ok, %{
        id: generate_id(),
        name: str_name,
        sku: str_sku,
        quantity: n_quantity,
        price: d_price,
        active: b_active
      }}
    end
  end

  @spec update_stock(String.t(), integer()) :: {:ok, map()} | {:error, String.t()}
  def update_stock(str_item_id, n_delta) do
    obj_item = fetch_item(str_item_id)
    n_new_quantity = obj_item.quantity + n_delta

    if n_new_quantity < 0 do
      {:error, "Insufficient stock"}
    else
      {:ok, %{obj_item | quantity: n_new_quantity}}
    end
  end

  @spec search_items(String.t(), list()) :: list(map())
  def search_items(str_query, arr_items) do
    str_lower_query = String.downcase(str_query)

    Enum.filter(arr_items, fn obj_item ->
      String.contains?(String.downcase(obj_item.name), str_lower_query) ||
        String.contains?(String.downcase(obj_item.sku), str_lower_query)
    end)
  end

  @spec calculate_value(list()) :: float()
  def calculate_value(arr_items) do
    Enum.reduce(arr_items, 0.0, fn obj_item, n_acc ->
      n_acc + obj_item.quantity * obj_item.price
    end)
  end

  @spec apply_discount(list(), float(), function()) :: list(map())
  def apply_discount(arr_items, d_discount_rate, fn_filter) do
    arr_items
    |> Enum.filter(fn_filter)
    |> Enum.map(fn obj_item ->
      d_new_price = Float.round(obj_item.price * (1 - d_discount_rate), 2)
      %{obj_item | price: d_new_price}
    end)
  end

  @spec group_by_category(list()) :: map()
  def group_by_category(arr_items) do
    Enum.group_by(arr_items, fn obj_item -> obj_item.category end)
  end

  @spec low_stock_report(list(), integer()) :: list(map())
  def low_stock_report(arr_items, n_threshold) do
    b_include_inactive = false

    arr_items
    |> Enum.filter(fn obj_item ->
      obj_item.quantity <= n_threshold &&
        (b_include_inactive || obj_item.active)
    end)
    |> Enum.sort_by(fn obj_item -> obj_item.quantity end)
  end

  defp fetch_item(str_id), do: %{id: str_id, name: "Item", sku: "SKU", quantity: 10, price: 9.99, active: true, category: "misc"}
  defp generate_id, do: System.unique_integer([:positive]) |> to_string()
end
