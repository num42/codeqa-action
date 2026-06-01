defmodule MyApp.Payments do
  @moduledoc """
  Public API for processing payments and managing charges.

  All monetary amounts are in the smallest currency unit (e.g. cents for USD).
  Currency codes follow ISO 4217 (e.g. `:usd`, `:eur`).

  ## Usage

      {:ok, charge} = MyApp.Payments.charge(customer_id, 2999, :usd)
      {:ok, _} = MyApp.Payments.refund(charge.id, 2999)
  """

  alias MyApp.Payments.{Charge, Refund}
  alias MyApp.Repo

  @doc """
  Creates a charge against a customer's default payment method.

  `amount` must be a positive integer in the smallest currency unit.
  `currency` must be one of `:usd`, `:eur`, or `:gbp`.

  Returns `{:ok, charge}` on success, or `{:error, reason}` when the
  customer has no payment method, the card is declined, or validation fails.
  """
  @spec charge(integer(), pos_integer(), :usd | :eur | :gbp) ::
          {:ok, Charge.t()} | {:error, atom()}
  def charge(customer_id, amount, currency)
      when is_integer(amount) and amount > 0 do
    with {:ok, pm} <- fetch_default_payment_method(customer_id),
         {:ok, result} <- MyApp.PaymentGateway.charge(pm.token, amount, currency) do
      insert_charge(customer_id, amount, currency, result.transaction_id)
    end
  end

  @doc """
  Refunds a charge fully or partially.

  `amount` must not exceed the original charge amount. Pass the full charge
  amount to issue a full refund.

  Returns `{:ok, refund}` or `{:error, :exceeds_original}` when the requested
  amount is greater than the charge amount.
  """
  @spec refund(integer(), pos_integer()) :: {:ok, Refund.t()} | {:error, atom()}
  def refund(charge_id, amount) when is_integer(amount) and amount > 0 do
    with {:ok, charge} <- fetch_charge(charge_id),
         :ok <- validate_refund_amount(charge, amount),
         {:ok, result} <- MyApp.PaymentGateway.refund(charge.transaction_id, amount) do
      insert_refund(charge, amount, result.refund_id)
    end
  end

  @doc """
  Lists all charges for a customer, ordered by most recent first.

  `opts` supports `:limit` (default 20) and `:offset` (default 0).
  """
  @spec list_charges(integer(), keyword()) :: [Charge.t()]
  def list_charges(customer_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    Repo.all(
      from c in Charge,
        where: c.customer_id == ^customer_id,
        order_by: [desc: c.inserted_at],
        limit: ^limit,
        offset: ^offset
    )
  end

  defp fetch_default_payment_method(customer_id) do
    case Repo.get_by(MyApp.Payments.PaymentMethod, customer_id: customer_id, default: true) do
      nil -> {:error, :no_payment_method}
      pm -> {:ok, pm}
    end
  end

  defp fetch_charge(charge_id) do
    case Repo.get(Charge, charge_id) do
      nil -> {:error, :charge_not_found}
      charge -> {:ok, charge}
    end
  end

  defp validate_refund_amount(%Charge{amount: orig}, amount) when amount > orig do
    {:error, :exceeds_original}
  end

  defp validate_refund_amount(_, _), do: :ok

  defp insert_charge(customer_id, amount, currency, transaction_id) do
    %Charge{}
    |> Charge.changeset(%{
      customer_id: customer_id,
      amount: amount,
      currency: currency,
      transaction_id: transaction_id
    })
    |> Repo.insert()
  end

  defp insert_refund(charge, amount, refund_id) do
    %Refund{}
    |> Refund.changeset(%{charge_id: charge.id, amount: amount, refund_id: refund_id})
    |> Repo.insert()
  end
end
