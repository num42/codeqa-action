defmodule OrderService do
  @moduledoc "Handles order creation, validation, and fulfillment"

  def create_order(nil, _items), do: {:error, :user_required}
  def create_order(_user, []), do: {:error, :items_required}

  def create_order(user, items) do
    total = calculate_total(items)
    {:ok, %{user_id: user.id, items: items, total: total}}
  end

  def cancel_order(%{status: :pending} = order) do
    {:ok, %{order | status: :cancelled}}
  end

  def cancel_order(%{status: :shipped}) do
    {:error, :already_shipped}
  end

  def cancel_order(_order) do
    {:error, :invalid_status}
  end

  def apply_discount(order, code) do
    case lookup_discount(code) do
      nil ->
        {:error, :invalid_code}

      discount ->
        new_total = order.total * (1 - discount.rate)
        {:ok, %{order | total: new_total}}
    end
  end

  def validate_address(%{zip: nil}), do: {:error, :zip_required}
  def validate_address(%{city: nil}), do: {:error, :city_required}
  def validate_address(address), do: {:ok, address}

  def fulfill_order(%{payment_status: :paid} = order) do
    updated = %{order | status: :fulfilling}
    schedule_shipment(updated)
    notify_warehouse(updated)
    {:ok, updated}
  end

  def fulfill_order(%{payment_status: :pending}) do
    {:error, :payment_pending}
  end

  def fulfill_order(%{payment_status: :failed}) do
    {:error, :payment_failed}
  end

  defp calculate_total(items), do: Enum.sum(Enum.map(items, & &1.price))
  defp lookup_discount(_code), do: nil
  defp schedule_shipment(_order), do: :ok
  defp notify_warehouse(_order), do: :ok
end
