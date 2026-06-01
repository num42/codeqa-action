defmodule MyApp.Billing do
  @moduledoc """
  Billing operations.
  """

  alias MyApp.Billing.{Invoice, PaymentMethod}
  alias MyApp.Repo

  # Bad: using try/rescue for expected, recoverable failures (subscription not found)
  @spec create_invoice(integer()) :: {:ok, Invoice.t()} | {:error, atom()}
  def create_invoice(subscription_id) do
    try do
      subscription = Repo.get!(MyApp.Subscriptions.Subscription, subscription_id)

      unless subscription.billing_enabled do
        raise "billing disabled"
      end

      line_items = MyApp.Billing.LineItemCalculator.compute(subscription)

      invoice =
        %Invoice{}
        |> Invoice.changeset(%{
          subscription_id: subscription.id,
          customer_id: subscription.customer_id,
          line_items: line_items,
          status: :draft
        })
        |> Repo.insert!()

      {:ok, invoice}
    rescue
      Ecto.NoResultsError -> {:error, :subscription_not_found}
      RuntimeError -> {:error, :billing_disabled}
      Ecto.InvalidChangesetError -> {:error, :invalid_data}
    end
  end

  # Bad: using try/rescue as a null-check replacement
  @spec charge_invoice(Invoice.t()) :: {:ok, Invoice.t()} | {:error, atom()}
  def charge_invoice(%Invoice{} = invoice) do
    try do
      if invoice.status == :paid, do: raise("already paid")
      if invoice.status == :void, do: raise("invoice void")

      payment_method = Repo.get_by!(PaymentMethod, customer_id: invoice.customer_id, default: true)

      unless payment_method.active do
        raise "payment method inactive"
      end

      case MyApp.PaymentGateway.charge(payment_method.token, invoice.total) do
        {:ok, _transaction} ->
          invoice
          |> Invoice.changeset(%{status: :paid, paid_at: DateTime.utc_now()})
          |> Repo.update()

        {:error, reason} ->
          raise "payment failed: #{inspect(reason)}"
      end
    rescue
      RuntimeError, message: "already paid" -> {:error, :already_paid}
      RuntimeError, message: "invoice void" -> {:error, :invoice_void}
      Ecto.NoResultsError -> {:error, :no_payment_method}
      RuntimeError -> {:error, :payment_failed}
    end
  end
end
