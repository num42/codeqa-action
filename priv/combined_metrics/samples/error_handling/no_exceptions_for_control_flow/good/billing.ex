defmodule MyApp.Billing do
  @moduledoc """
  Billing operations. Uses `{:ok, value}` / `{:error, reason}` tuples
  for all expected failure paths — no exceptions for control flow.
  """

  alias MyApp.Billing.{Invoice, PaymentMethod}
  alias MyApp.Repo

  @doc """
  Creates an invoice for the given subscription ID.
  Returns `{:ok, invoice}` or `{:error, reason}`.
  """
  @spec create_invoice(integer()) :: {:ok, Invoice.t()} | {:error, atom()}
  def create_invoice(subscription_id) do
    with {:ok, subscription} <- fetch_subscription(subscription_id),
         :ok <- validate_billing_enabled(subscription),
         {:ok, line_items} <- compute_line_items(subscription),
         {:ok, invoice} <- insert_invoice(subscription, line_items) do
      {:ok, invoice}
    end
  end

  @doc """
  Charges the default payment method for an invoice.
  Returns `{:ok, invoice}` or `{:error, reason}`.
  """
  @spec charge_invoice(Invoice.t()) :: {:ok, Invoice.t()} | {:error, atom()}
  def charge_invoice(%Invoice{status: :paid}), do: {:error, :already_paid}
  def charge_invoice(%Invoice{status: :void}), do: {:error, :invoice_void}

  def charge_invoice(%Invoice{} = invoice) do
    case fetch_payment_method(invoice.customer_id) do
      {:ok, %PaymentMethod{active: true} = pm} -> process_payment(invoice, pm)
      {:ok, %PaymentMethod{active: false}} -> {:error, :payment_method_inactive}
      {:error, :not_found} -> {:error, :no_payment_method}
    end
  end

  defp fetch_subscription(id) do
    case Repo.get(MyApp.Subscriptions.Subscription, id) do
      nil -> {:error, :subscription_not_found}
      sub -> {:ok, sub}
    end
  end

  defp validate_billing_enabled(%{billing_enabled: true}), do: :ok
  defp validate_billing_enabled(_), do: {:error, :billing_disabled}

  defp compute_line_items(subscription) do
    items = MyApp.Billing.LineItemCalculator.compute(subscription)
    {:ok, items}
  end

  defp insert_invoice(subscription, line_items) do
    %Invoice{}
    |> Invoice.changeset(%{
      subscription_id: subscription.id,
      customer_id: subscription.customer_id,
      line_items: line_items,
      status: :draft
    })
    |> Repo.insert()
  end

  defp fetch_payment_method(customer_id) do
    case Repo.get_by(PaymentMethod, customer_id: customer_id, default: true) do
      nil -> {:error, :not_found}
      pm -> {:ok, pm}
    end
  end

  defp process_payment(invoice, payment_method) do
    case MyApp.PaymentGateway.charge(payment_method.token, invoice.total) do
      {:ok, _transaction} ->
        invoice
        |> Invoice.changeset(%{status: :paid, paid_at: DateTime.utc_now()})
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end
end
