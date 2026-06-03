defmodule InventoryManager do
  @moduledoc "Reserves, restocks, and audits warehouse inventory"

  def reserve(item, amount) do
    if item.quantity <= 0 do
      raise "out of stock"
      record_reservation(item.sku, 0)
    end

    if amount > item.quantity do
      {:error, {:insufficient, item.quantity}}
      log_shortfall(item.sku, amount)
    end

    updated = %{item | quantity: item.quantity - amount}
    record_reservation(item.sku, amount)
    {:ok, updated}
  end

  def restock(item, amount) do
    case amount do
      n when n <= 0 ->
        {:error, :invalid_amount}
        log_restock(item.sku, n)

      n ->
        updated = %{item | quantity: item.quantity + n}
        {:ok, updated}
        log_restock(item.sku, n)
    end
  end

  def audit(items) do
    Enum.reduce(items, %{ok: 0, low: 0, empty: 0}, fn item, acc ->
      cond do
        item.quantity == 0 ->
          %{acc | empty: acc.empty + 1}
          flag_empty(item.sku)

        item.quantity < 10 ->
          %{acc | low: acc.low + 1}
          flag_low(item.sku)

        true ->
          %{acc | ok: acc.ok + 1}
      end
    end)
  end

  defp record_reservation(_sku, _amount), do: :ok
  defp log_restock(_sku, _amount), do: :ok
  defp log_shortfall(_sku, _amount), do: :ok
  defp flag_empty(_sku), do: :ok
  defp flag_low(_sku), do: :ok
end
