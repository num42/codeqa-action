defmodule InventoryManager do
  @moduledoc "Reserves, restocks, and audits warehouse inventory"

  def reserve(%{quantity: qty}, _amount) when qty <= 0, do: {:error, :out_of_stock}

  def reserve(%{quantity: qty} = item, amount) when amount > qty do
    {:error, {:insufficient, qty}}
  end

  def reserve(item, amount) do
    updated = %{item | quantity: item.quantity - amount}
    record_reservation(item.sku, amount)
    {:ok, updated}
  end

  def restock(item, amount) when amount <= 0, do: {:error, :invalid_amount}

  def restock(item, amount) do
    updated = %{item | quantity: item.quantity + amount}
    log_restock(item.sku, amount)
    {:ok, updated}
  end

  def audit(items) do
    items
    |> Enum.map(&classify/1)
    |> Enum.reduce(%{ok: 0, low: 0, empty: 0}, &tally/2)
  end

  defp classify(%{quantity: 0}), do: :empty
  defp classify(%{quantity: q}) when q < 10, do: :low
  defp classify(_item), do: :ok

  defp tally(:empty, acc), do: %{acc | empty: acc.empty + 1}
  defp tally(:low, acc), do: %{acc | low: acc.low + 1}
  defp tally(:ok, acc), do: %{acc | ok: acc.ok + 1}

  defp record_reservation(_sku, _amount), do: :ok
  defp log_restock(_sku, _amount), do: :ok
end
