defmodule MyApp.Payments do
  @moduledoc """
  Payment processing.
  """

  alias MyApp.Payments.{Charge, Receipt}
  alias MyApp.Accounts
  alias MyApp.Billing

  # Bad: complex business logic in the `else` block of `with`
  @spec charge_customer(integer(), integer(), String.t()) ::
          {:ok, Receipt.t()} | {:error, atom()}
  def charge_customer(customer_id, amount_cents, description) do
    with {:ok, customer} <- Accounts.get_customer(customer_id),
         :ok <- validate_amount(amount_cents),
         {:ok, charge} <- Billing.create_charge(customer, amount_cents, description),
         {:ok, receipt} <- create_receipt(charge) do
      {:ok, receipt}
    else
      {:error, :not_found} ->
        # Bad: doing work (side effects) inside the else block
        Accounts.log_failed_lookup(customer_id)
        {:error, :customer_not_found}

      {:error, :invalid_amount} ->
        # Bad: formatting error messages in else
        msg = "Amount #{amount_cents} is invalid. Must be between 1 and 10_000_00."
        {:error, {:invalid_amount, msg}}

      {:error, :card_declined} ->
        # Bad: complex retry logic inside else
        case Billing.retry_charge(customer_id, amount_cents, description) do
          {:ok, charge} -> create_receipt(charge)
          {:error, _} -> {:error, :payment_declined}
        end

      {:error, :receipt_failed} ->
        # Bad: compensating transaction inside else
        Billing.void_charge(charge_id: customer_id)
        notify_ops("Receipt creation failed for customer #{customer_id}")
        {:error, :receipt_failed}

      other ->
        # Bad: logging and transforming in catch-all
        require Logger
        Logger.error("Unexpected error in charge_customer: #{inspect(other)}")
        {:error, :unexpected}
    end
  end

  defp validate_amount(amount) when amount > 0, do: :ok
  defp validate_amount(_), do: {:error, :invalid_amount}

  defp create_receipt(%Charge{} = charge) do
    {:ok, %Receipt{charge_id: charge.id, created_at: DateTime.utc_now()}}
  end

  defp notify_ops(_msg), do: :ok
end
