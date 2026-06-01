defmodule OrderProcessor do
  def process(%{status: :new, payment_method: :card} = order) do
    with :ok <- verify_user(order),
         :ok <- require_items(order),
         {:ok, charge} <- charge_card(order) do
      maybe_alert_fraud(order)
      {:ok, %{order | status: :paid, charge_id: charge.id}}
    end
  end

  def process(%{status: :new, payment_method: :invoice} = order) do
    if order.user.credit_approved do
      {:ok, %{order | status: :invoiced}}
    else
      {:error, :credit_not_approved}
    end
  end

  def process(%{status: :paid} = order) do
    case order.shipment_address do
      nil -> {:error, :no_address}
      _ -> {:ok, %{order | status: :shipped}}
    end
  end

  def process(%{status: :shipped} = order) do
    {:ok, %{order | status: :delivered}}
  end

  def process(%{status: :cancelled}) do
    {:error, :already_cancelled}
  end

  def process(_order), do: {:error, :invalid_transition}

  defp verify_user(%{user: %{verified: true}}), do: :ok
  defp verify_user(_), do: {:error, :unverified_user}

  defp require_items(%{items: []}), do: {:error, :empty_order}
  defp require_items(_), do: :ok

  defp maybe_alert_fraud(%{total: total} = order) when total > 1000 do
    notify_fraud_team(order)
  end

  defp maybe_alert_fraud(_order), do: :ok

  defp charge_card(order), do: {:ok, %{id: "ch_#{order.id}"}}
  defp notify_fraud_team(order), do: IO.puts("Fraud check: #{order.id}")
end
