defmodule MyApp.Payments do
  @moduledoc """
  Payment processing. Uses `with` exclusively for the happy path,
  keeping the `else` block minimal and declarative.
  """

  alias MyApp.Payments.{Charge, Receipt}
  alias MyApp.Accounts
  alias MyApp.Billing

  @doc """
  Charges a customer and creates a receipt. Returns `{:ok, receipt}`
  or a tagged error tuple describing what went wrong.
  """
  @spec charge_customer(integer(), integer(), String.t()) ::
          {:ok, Receipt.t()} | {:error, atom()}
  def charge_customer(customer_id, amount_cents, description) do
    with {:ok, customer} <- Accounts.get_customer(customer_id),
         :ok <- validate_amount(amount_cents),
         {:ok, charge} <- Billing.create_charge(customer, amount_cents, description),
         {:ok, receipt} <- create_receipt(charge) do
      {:ok, receipt}
    else
      {:error, :not_found} -> {:error, :customer_not_found}
      {:error, :invalid_amount} -> {:error, :invalid_amount}
      {:error, :card_declined} -> {:error, :payment_declined}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Refunds a charge partially or fully.
  """
  @spec refund(integer(), integer()) :: {:ok, Charge.t()} | {:error, atom()}
  def refund(charge_id, amount_cents) do
    with {:ok, charge} <- Billing.get_charge(charge_id),
         :ok <- validate_refundable(charge, amount_cents),
         {:ok, updated} <- Billing.apply_refund(charge, amount_cents) do
      {:ok, updated}
    else
      {:error, :not_found} -> {:error, :charge_not_found}
      {:error, :exceeds_original} -> {:error, :refund_exceeds_original}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_amount(amount) when amount > 0 and amount <= 100_000_00, do: :ok
  defp validate_amount(_), do: {:error, :invalid_amount}

  defp validate_refundable(%Charge{refundable: false}, _), do: {:error, :not_refundable}
  defp validate_refundable(%Charge{amount: orig}, refund) when refund > orig do
    {:error, :exceeds_original}
  end
  defp validate_refundable(_, _), do: :ok

  defp create_receipt(%Charge{} = charge) do
    {:ok, %Receipt{charge_id: charge.id, created_at: DateTime.utc_now()}}
  end
end
