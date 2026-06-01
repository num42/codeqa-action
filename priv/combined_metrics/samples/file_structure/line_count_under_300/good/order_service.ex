defmodule OrderService do
  @moduledoc """
  Manages order lifecycle: creation, updates, and cancellation.
  """

  alias OrderService.{Order, Repo}

  @spec create_order(map()) :: {:ok, Order.t()} | {:error, String.t()}
  def create_order(attrs) do
    with {:ok, validated} <- validate_order_attrs(attrs),
         {:ok, order} <- Repo.insert(Order, validated) do
      {:ok, order}
    end
  end

  @spec get_order(String.t()) :: {:ok, Order.t()} | {:error, :not_found}
  def get_order(order_id) do
    case Repo.find(Order, order_id) do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  @spec list_orders_for_user(String.t()) :: {:ok, list(Order.t())}
  def list_orders_for_user(user_id) do
    orders = Repo.all(Order, user_id: user_id)
    {:ok, orders}
  end

  @spec update_order(String.t(), map()) :: {:ok, Order.t()} | {:error, :not_found | String.t()}
  def update_order(order_id, attrs) do
    with {:ok, order} <- get_order(order_id),
         {:ok, validated} <- validate_order_attrs(attrs),
         {:ok, updated} <- Repo.update(order, validated) do
      {:ok, updated}
    end
  end

  @spec cancel_order(String.t()) :: {:ok, Order.t()} | {:error, :not_found | :already_cancelled}
  def cancel_order(order_id) do
    case get_order(order_id) do
      {:error, :not_found} ->
        {:error, :not_found}
      {:ok, %Order{status: :cancelled}} ->
        {:error, :already_cancelled}
      {:ok, order} ->
        Repo.update(order, %{status: :cancelled})
    end
  end

  @spec complete_order(String.t()) :: {:ok, Order.t()} | {:error, :not_found | :not_fulfillable}
  def complete_order(order_id) do
    with {:ok, order} <- get_order(order_id),
         :ok <- ensure_fulfillable(order),
         {:ok, completed} <- Repo.update(order, %{status: :completed}) do
      {:ok, completed}
    end
  end

  defp validate_order_attrs(%{items: items}) when is_list(items) and length(items) > 0 do
    {:ok, items}
  end

  defp validate_order_attrs(_), do: {:error, "Order must contain at least one item"}

  defp ensure_fulfillable(%Order{status: :pending}), do: :ok
  defp ensure_fulfillable(_), do: {:error, :not_fulfillable}
end
