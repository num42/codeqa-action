defmodule MyApp.Payments do
  # Bad: no @moduledoc — the module's purpose, conventions, and usage
  # are completely undiscoverable without reading the full source.

  alias MyApp.Payments.{Charge, Refund}
  alias MyApp.Repo

  # Bad: no @doc on a public function. Callers cannot use `h MyApp.Payments.charge/3`
  # in IEx, and documentation tools will not generate an entry for this function.
  @spec charge(integer(), pos_integer(), :usd | :eur | :gbp) ::
          {:ok, Charge.t()} | {:error, atom()}
  def charge(customer_id, amount, currency)
      when is_integer(amount) and amount > 0 do
    with {:ok, pm} <- fetch_default_payment_method(customer_id),
         {:ok, result} <- MyApp.PaymentGateway.charge(pm.token, amount, currency) do
      insert_charge(customer_id, amount, currency, result.transaction_id)
    end
  end

  # Bad: no @doc on this public function either
  @spec refund(integer(), pos_integer()) :: {:ok, Refund.t()} | {:error, atom()}
  def refund(charge_id, amount) when is_integer(amount) and amount > 0 do
    with {:ok, charge} <- fetch_charge(charge_id),
         :ok <- validate_refund_amount(charge, amount),
         {:ok, result} <- MyApp.PaymentGateway.refund(charge.transaction_id, amount) do
      insert_refund(charge, amount, result.refund_id)
    end
  end

  # Bad: `list_charges/2` is public but completely undocumented.
  # What does `opts` accept? What order are results in?
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
