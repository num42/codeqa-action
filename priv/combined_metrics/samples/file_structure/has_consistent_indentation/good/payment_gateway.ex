defmodule Billing.PaymentGateway do
  @moduledoc """
  Public API for charging customers through an external payment provider.

  This module is doc-heavy on purpose: it carries a large `@moduledoc`,
  per-function `@doc` annotations, and several `@type`/`@callback`
  definitions. Despite all the documentation, the indentation stays a
  single consistent 2-space style throughout — GOOD.

  ## Lifecycle

      iex> Billing.PaymentGateway.authorize(%{amount: 1299, token: "tok_1"})
      {:ok, %{status: :authorized, amount: 1299}}

  Every public function returns a tagged tuple so callers can pattern
  match on success or failure without rescuing exceptions.
  """

  @typedoc "Amount to charge, in integer cents."
  @type cents :: non_neg_integer()

  @typedoc "Opaque provider token identifying a payment method."
  @type token :: String.t()

  @typedoc "Result of a charge attempt."
  @type charge_result :: {:ok, map()} | {:error, atom()}

  @doc """
  Behaviour contract implemented by concrete provider adapters
  (Stripe, Adyen, ...). Adapters translate provider responses into the
  tagged tuples documented above.
  """
  @callback charge(token(), cents()) :: charge_result()

  @doc """
  Authorizes a charge without capturing it.

  Returns `{:ok, map}` on success or `{:error, reason}` when the amount
  is non-positive or the token is missing.
  """
  @spec authorize(map()) :: charge_result()
  def authorize(%{amount: amount, token: token})
      when is_integer(amount) and amount > 0 and is_binary(token) do
    {:ok, %{status: :authorized, amount: amount}}
  end

  def authorize(_params) do
    {:error, :invalid_request}
  end

  @doc """
  Captures a previously authorized charge.
  """
  @spec capture(map()) :: charge_result()
  def capture(%{status: :authorized} = auth) do
    {:ok, %{auth | status: :captured}}
  end

  def capture(_auth) do
    {:error, :not_authorized}
  end
end
