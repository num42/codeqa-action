defmodule MyApp.Inventory do
  @moduledoc """
  Inventory management.
  """

  alias MyApp.Inventory.{Product, StockLevel}
  alias MyApp.Repo

  # Bad: defensively wraps every operation in case, even when
  # the caller should just crash on truly unexpected failures
  @spec decrement_stock(integer(), pos_integer()) :: {:ok, StockLevel.t()} | {:error, atom()}
  def decrement_stock(product_id, quantity) do
    case Repo.get(Product, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        case Map.get(product, :stock) do
          nil ->
            {:error, :no_stock_field}

          current_stock ->
            if current_stock >= quantity do
              case product |> Product.changeset(%{stock: current_stock - quantity}) |> Repo.update() do
                {:ok, updated} -> {:ok, updated}
                {:error, changeset} -> {:error, changeset}
              end
            else
              {:error, :insufficient_stock}
            end
        end
    end
  end

  # Bad: wrapping every step in case when assertive matching would be clearer
  @spec process_replenishment(map()) :: :ok | {:error, atom()}
  def process_replenishment(event) do
    case Map.get(event, :product_id) do
      nil ->
        {:error, :missing_product_id}

      id ->
        case Map.get(event, :quantity) do
          nil ->
            {:error, :missing_quantity}

          qty ->
            case Repo.get(Product, id) do
              nil ->
                {:error, :product_not_found}

              product ->
                product
                |> Product.changeset(%{stock: product.stock + qty})
                |> Repo.update()

                :ok
            end
        end
    end
  end
end
