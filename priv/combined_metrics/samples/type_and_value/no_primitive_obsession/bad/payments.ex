defmodule MyApp.Payments do
  @moduledoc """
  Payment processing.
  """

  # Bad: money is a raw integer with no currency attached.
  # Nothing prevents mixing USD cents and EUR cents — silent bugs.
  @spec create_charge(integer(), integer()) :: {:ok, map()} | {:error, term()}
  def create_charge(order_id, amount_cents) do
    MyApp.PaymentGateway.charge(%{
      order_id: order_id,
      amount: amount_cents
    })
  end

  # Bad: tax calculation takes raw integers — no type safety,
  # result could be added to a different currency total by accident
  @spec calculate_tax(integer(), float()) :: integer()
  def calculate_tax(amount_cents, rate) do
    round(amount_cents * rate)
  end

  # Bad: applying discount to raw integer — what currency? what precision?
  @spec apply_discount(integer(), float()) :: integer()
  def apply_discount(amount_cents, discount_percent) do
    round(amount_cents * (1.0 - discount_percent / 100))
  end

  # Bad: function has no idea if `a` and `b` are same currency
  @spec add_amounts(integer(), integer()) :: integer()
  def add_amounts(a, b), do: a + b

  # Bad: passing a raw string for email, integer for user_id, integer for amount —
  # no domain types, caller must know implicit conventions (is this cents? dollars?)
  @spec send_receipt(integer(), String.t(), integer(), String.t()) :: :ok
  def send_receipt(user_id, email, amount_cents, currency_code) do
    formatted = :erlang.float_to_binary(amount_cents / 100, decimals: 2)
    MyApp.Mailer.send_text(email, "Receipt for user #{user_id}: #{currency_code} #{formatted}")
    :ok
  end

  # Bad: using a plain tuple to represent money — no struct enforcement
  @spec split(tuple(), integer()) :: [tuple()]
  def split({amount, currency}, parts) when parts > 0 do
    each = div(amount, parts)
    List.duplicate({each, currency}, parts)
  end
end
