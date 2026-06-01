defmodule Payment do
  @moduledoc "Handles payment processing and refunds"

  require Logger

  def charge(user, amount, card) do
    case validate_card(card) do
      {:ok, validated} ->
        result = call_payment_gateway(validated, amount)
        Logger.info("Payment charged", user_id: user.id, amount: amount)
        result

      {:error, reason} ->
        Logger.warning("Card validation failed", user_id: user.id, reason: inspect(reason))
        {:error, reason}
    end
  end

  def refund(transaction_id, amount) do
    case fetch_transaction(transaction_id) do
      {:ok, transaction} when transaction.amount >= amount ->
        result = call_refund_api(transaction, amount)
        Logger.info("Refund processed", transaction_id: transaction_id, amount: amount)
        result

      {:ok, _transaction} ->
        {:error, :exceeds_original}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def calculate_fee(amount, method) do
    case method do
      :credit_card -> amount * 0.029 + 0.30
      :debit_card -> amount * 0.015
      :bank_transfer -> 0.25
      _ -> amount * 0.035
    end
  end

  def authorize(user, amount) do
    if user.balance >= amount do
      {:ok, :authorized}
    else
      {:error, :insufficient_funds}
    end
  end

  def apply_coupon(total, coupon_code) do
    case lookup_coupon(coupon_code) do
      {:ok, coupon} ->
        {:ok, total - coupon.discount}

      {:error, _} ->
        {:error, :invalid_coupon}
    end
  end

  defp validate_card(card), do: {:ok, card}
  defp call_payment_gateway(_card, _amount), do: {:ok, %{transaction_id: "txn_123"}}
  defp fetch_transaction(_id), do: {:ok, %{amount: 100.0}}
  defp call_refund_api(_transaction, _amount), do: {:ok, :refunded}
  defp lookup_coupon(_code), do: {:error, :not_found}
end
