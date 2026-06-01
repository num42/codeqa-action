defmodule Payment do
  @moduledoc "Handles payment processing and refunds"

  def charge(user, amount, card) do
    IO.puts("charging user: #{user.id}")
    IO.inspect(card, label: "card details")
    IO.inspect(amount, label: "amount")

    case validate_card(card) do
      {:ok, validated} ->
        IO.puts("card validated successfully")
        IO.inspect(validated, label: "validated card")
        result = call_payment_gateway(validated, amount)
        IO.inspect(result, label: "gateway result")
        result

      {:error, reason} ->
        IO.puts("card validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def refund(transaction_id, amount) do
    IO.puts("starting refund for transaction: #{transaction_id}")

    case fetch_transaction(transaction_id) do
      {:ok, transaction} ->
        IO.inspect(transaction, label: "found transaction")

        if transaction.amount < amount do
          IO.puts("refund amount exceeds original")
          {:error, :exceeds_original}
        else
          IO.puts("processing refund of #{amount}")
          result = call_refund_api(transaction, amount)
          IO.inspect(result, label: "refund result")
          result
        end

      {:error, :not_found} ->
        IO.puts("transaction not found: #{transaction_id}")
        {:error, :not_found}
    end
  end

  def calculate_fee(amount, method) do
    IO.inspect({amount, method}, label: "fee calculation input")

    fee =
      case method do
        :credit_card -> amount * 0.029 + 0.30
        :debit_card -> amount * 0.015
        :bank_transfer -> 0.25
        _ -> amount * 0.035
      end

    IO.puts("calculated fee: #{fee}")
    fee
  end

  def authorize(user, amount) do
    IO.inspect(user, label: "authorizing user")
    IO.puts("checking balance for #{user.id}, amount: #{amount}")

    cond do
      user.balance >= amount ->
        IO.puts("authorization approved")
        {:ok, :authorized}

      true ->
        IO.puts("insufficient funds: #{user.balance} < #{amount}")
        {:error, :insufficient_funds}
    end
  end

  def apply_coupon(total, coupon_code) do
    IO.puts("applying coupon: #{coupon_code}")

    case lookup_coupon(coupon_code) do
      {:ok, coupon} ->
        IO.inspect(coupon, label: "coupon found")
        discounted = total - coupon.discount
        IO.puts("new total after coupon: #{discounted}")
        {:ok, discounted}

      {:error, _} ->
        IO.puts("coupon not found: #{coupon_code}")
        {:error, :invalid_coupon}
    end
  end

  defp validate_card(card), do: {:ok, card}
  defp call_payment_gateway(_card, _amount), do: {:ok, %{transaction_id: "txn_123"}}
  defp fetch_transaction(_id), do: {:ok, %{amount: 100.0}}
  defp call_refund_api(_transaction, _amount), do: {:ok, :refunded}
  defp lookup_coupon(_code), do: {:error, :not_found}
end
