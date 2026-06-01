defmodule Inventory.Good do
  @moduledoc """
  Inventory management without Hungarian notation prefixes.
  GOOD: name, is_active, count, items, age, user, callback, price — no type prefixes.
  """

  @spec add_item(map()) :: {:ok, map()} | {:error, String.t()}
  def add_item(item) do
    name = item.name
    sku = item.sku
    quantity = item.quantity
    price = item.price
    is_active = Map.get(item, :active, true)

    if name == "" or is_nil(name) do
      {:error, "Name is required"}
    else
      {:ok, %{
        id: generate_id(),
        name: name,
        sku: sku,
        quantity: quantity,
        price: price,
        active: is_active
      }}
    end
  end

  @spec update_stock(String.t(), integer()) :: {:ok, map()} | {:error, String.t()}
  def update_stock(item_id, delta) do
    item = fetch_item(item_id)
    new_quantity = item.quantity + delta

    if new_quantity < 0 do
      {:error, "Insufficient stock"}
    else
      {:ok, %{item | quantity: new_quantity}}
    end
  end

  @spec search_items(String.t(), list()) :: list(map())
  def search_items(query, items) do
    lower_query = String.downcase(query)

    Enum.filter(items, fn item ->
      String.contains?(String.downcase(item.name), lower_query) ||
        String.contains?(String.downcase(item.sku), lower_query)
    end)
  end

  @spec calculate_value(list()) :: float()
  def calculate_value(items) do
    Enum.reduce(items, 0.0, fn item, acc ->
      acc + item.quantity * item.price
    end)
  end

  @spec apply_discount(list(), float(), function()) :: list(map())
  def apply_discount(items, discount_rate, filter) do
    items
    |> Enum.filter(filter)
    |> Enum.map(fn item ->
      new_price = Float.round(item.price * (1 - discount_rate), 2)
      %{item | price: new_price}
    end)
  end

  @spec group_by_category(list()) :: map()
  def group_by_category(items) do
    Enum.group_by(items, fn item -> item.category end)
  end

  @spec low_stock_report(list(), integer()) :: list(map())
  def low_stock_report(items, threshold) do
    include_inactive = false

    items
    |> Enum.filter(fn item ->
      item.quantity <= threshold &&
        (include_inactive || item.active)
    end)
    |> Enum.sort_by(fn item -> item.quantity end)
  end

  defp fetch_item(id), do: %{id: id, name: "Item", sku: "SKU", quantity: 10, price: 9.99, active: true, category: "misc"}
  defp generate_id, do: System.unique_integer([:positive]) |> to_string()
end
