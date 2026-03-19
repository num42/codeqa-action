defmodule MyApp.Payments do
  @moduledoc """
  Payment processing. Domain concepts like money are represented as
  dedicated structs rather than raw primitives.
  """

  defmodule Money do
    @moduledoc "Represents a monetary amount with an explicit currency."
    @enforce_keys [:amount, :currency]
    defstruct [:amount, :currency]

    @type t :: %__MODULE__{amount: integer(), currency: :usd | :eur | :gbp}

    def new(amount, currency) when is_integer(amount) and amount >= 0 do
      %__MODULE__{amount: amount, currency: currency}
    end

    def add(%__MODULE__{amount: a, currency: c}, %__MODULE__{amount: b, currency: c}) do
      %__MODULE__{amount: a + b, currency: c}
    end

    def add(_, _), do: raise(ArgumentError, "cannot add money with different currencies")

    def format(%__MODULE__{amount: amount, currency: :usd}) do
      "$#{:erlang.float_to_binary(amount / 100, decimals: 2)}"
    end

    def format(%__MODULE__{amount: amount, currency: :eur}) do
      "€#{:erlang.float_to_binary(amount / 100, decimals: 2)}"
    end
  end

  defmodule OrderId do
    @moduledoc "Typed wrapper for an order identifier."
    @enforce_keys [:value]
    defstruct [:value]

    @type t :: %__MODULE__{value: integer()}

    def new(id) when is_integer(id) and id > 0, do: %__MODULE__{value: id}
  end

  @doc """
  Creates a charge for an order. Accepts typed structs, not raw integers.
  """
  @spec create_charge(OrderId.t(), Money.t()) :: {:ok, map()} | {:error, term()}
  def create_charge(%OrderId{value: order_id}, %Money{amount: amount, currency: currency}) do
    MyApp.PaymentGateway.charge(%{
      order_id: order_id,
      amount: amount,
      currency: currency
    })
  end

  @doc """
  Calculates tax as a Money struct, preserving currency information.
  """
  @spec calculate_tax(Money.t(), float()) :: Money.t()
  def calculate_tax(%Money{amount: amount, currency: currency}, rate) do
    tax = round(amount * rate)
    Money.new(tax, currency)
  end
end
