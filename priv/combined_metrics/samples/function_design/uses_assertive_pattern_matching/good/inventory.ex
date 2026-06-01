defmodule MyApp.Inventory do
  @moduledoc """
  Inventory management. Uses assertive pattern matching — functions
  bind expected shapes directly and crash on unexpected input rather
  than defensively guarding every case.
  """

  alias MyApp.Inventory.{Product, StockLevel}
  alias MyApp.Repo

  @doc """
  Decrements stock for a product. Expects `{:ok, product}` from the
  upstream call and binds it directly.
  """
  @spec decrement_stock(integer(), pos_integer()) :: {:ok, StockLevel.t()} | {:error, :insufficient_stock}
  def decrement_stock(product_id, quantity) do
    # Assertive: crash if get_product!/1 raises — we don't silently swallow missing products
    product = Repo.get!(Product, product_id)

    # Assertive: pattern match the struct's stock field directly
    %Product{stock: current_stock} = product

    if current_stock >= quantity do
      product
      |> Product.changeset(%{stock: current_stock - quantity})
      |> Repo.update()
    else
      {:error, :insufficient_stock}
    end
  end

  @doc """
  Processes a stock replenishment event from the warehouse feed.
  Asserts the expected map shape and crashes on malformed input.
  """
  @spec process_replenishment(map()) :: :ok
  def process_replenishment(%{product_id: id, quantity: qty, warehouse: wh}) do
    product = Repo.get!(Product, id)

    product
    |> Product.changeset(%{stock: product.stock + qty, last_warehouse: wh})
    |> Repo.update!()

    :ok
  end

  @doc """
  Transfers stock between warehouses. Asserts both locations exist.
  """
  @spec transfer(integer(), String.t(), String.t(), pos_integer()) :: {:ok, map()} | {:error, term()}
  def transfer(product_id, from_warehouse, to_warehouse, quantity) do
    {:ok, product} = Repo.fetch(Product, product_id)
    %Product{stock_by_warehouse: stock_map} = product

    # Assertive access — crashes if warehouse key is missing
    from_stock = Map.fetch!(stock_map, from_warehouse)

    updated =
      stock_map
      |> Map.put(from_warehouse, from_stock - quantity)
      |> Map.update!(to_warehouse, &(&1 + quantity))

    product
    |> Product.changeset(%{stock_by_warehouse: updated})
    |> Repo.update()
  end
end
