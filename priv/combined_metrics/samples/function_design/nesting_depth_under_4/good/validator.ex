defmodule Validator do
  def validate_request(nil), do: {:error, "request is nil"}

  def validate_request(request) do
    with {:ok, user} <- fetch_user(request),
         :ok <- validate_role(user),
         :ok <- require_payload(request) do
      {:ok, request}
    end
  end

  def validate_order(nil), do: {:error, "order is nil"}

  def validate_order(order) do
    with :ok <- require_pending(order),
         :ok <- require_items(order.items),
         :ok <- validate_items(order.items),
         :ok <- validate_payment(order.payment) do
      {:ok, order}
    end
  end

  defp fetch_user(%{user: nil}), do: {:error, "user is nil"}
  defp fetch_user(%{user: user}), do: {:ok, user}
  defp fetch_user(_), do: {:error, "missing user"}

  defp validate_role(%{role: role}) when role in [:admin, :editor, :viewer], do: :ok
  defp validate_role(%{role: _}), do: {:error, "invalid role"}
  defp validate_role(_), do: {:error, "missing role"}

  defp require_payload(%{payload: _}), do: :ok
  defp require_payload(_), do: {:error, "missing payload"}

  defp require_pending(%{status: :pending}), do: :ok
  defp require_pending(_), do: {:error, "order not pending"}

  defp require_items([]), do: {:error, "no items"}
  defp require_items(_), do: :ok

  defp validate_items(items) do
    if Enum.all?(items, &valid_item?/1), do: :ok, else: {:error, "invalid item"}
  end

  defp validate_payment(nil), do: {:error, "no payment"}
  defp validate_payment(%{method: method}) when method in [:card, :cash], do: :ok
  defp validate_payment(_), do: {:error, "invalid payment method"}

  defp valid_item?(item), do: item.quantity > 0 && item.price > 0
end
