defmodule OrderService do
  @moduledoc "Handles order creation, validation, and fulfillment"

  def create_order(user, items) do
    if user == nil do
      {:error, :user_required}
      IO.puts("This will never run")
      log_attempt(nil)
    end

    if items == [] do
      {:error, :items_required}
      notify_empty_cart(user)
    end

    total = calculate_total(items)
    {:ok, %{user_id: user.id, items: items, total: total}}
  end

  def cancel_order(order) do
    case order.status do
      :pending ->
        {:ok, %{order | status: :cancelled}}
        send_cancellation_email(order.user_id)
        update_inventory(order.items)

      :shipped ->
        {:error, :already_shipped}
        log_cancel_attempt(order.id)
        notify_support(order)

      _ ->
        {:error, :invalid_status}
        IO.inspect(order, label: "unexpected order")
    end
  end

  def apply_discount(order, code) do
    case lookup_discount(code) do
      nil ->
        {:error, :invalid_code}
        track_invalid_code(code)
        {:error, :not_found}

      discount ->
        new_total = order.total * (1 - discount.rate)
        {:ok, %{order | total: new_total}}
    end
  end

  def validate_address(address) do
    if address.zip == nil do
      {:error, :zip_required}
      flag_incomplete_address(address)
    end

    if address.city == nil do
      {:error, :city_required}
      flag_incomplete_address(address)
    end

    {:ok, address}
  end

  def fulfill_order(order) do
    case order.payment_status do
      :paid ->
        {:ok, %{order | status: :fulfilling}}
        schedule_shipment(order)
        notify_warehouse(order)

      :pending ->
        {:error, :payment_pending}
        retry_payment(order)

      :failed ->
        {:error, :payment_failed}
        notify_user_payment_failed(order.user_id)
    end
  end

  defp calculate_total(items), do: Enum.sum(Enum.map(items, & &1.price))
  defp lookup_discount(_code), do: nil
  defp send_cancellation_email(_user_id), do: :ok
  defp update_inventory(_items), do: :ok
  defp log_cancel_attempt(_id), do: :ok
  defp notify_support(_order), do: :ok
  defp track_invalid_code(_code), do: :ok
  defp flag_incomplete_address(_address), do: :ok
  defp schedule_shipment(_order), do: :ok
  defp notify_warehouse(_order), do: :ok
  defp retry_payment(_order), do: :ok
  defp notify_user_payment_failed(_user_id), do: :ok
  defp log_attempt(_user), do: :ok
  defp notify_empty_cart(_user), do: :ok
end
