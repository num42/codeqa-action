defmodule MyApp.Billing.Formatter do
  @moduledoc """
  Formatting utilities for billing amounts and invoice references.
  """

  @doc """
  Formats an integer amount in cents to a display string for the given currency.

  For example, passing 2999 and :usd would return a string like "$29.99".
  Passing 0 for any currency returns "0.00" with the appropriate symbol.
  For unknown currencies the amount is formatted without a symbol prefix.

  Note that the function expects a non-negative integer for cents.
  Negative values are not supported and may produce unexpected output.
  The currency atom should be one of :usd, :eur, or :gbp for proper
  symbol formatting. Other atoms fall back to an uppercase string suffix.
  """
  # Bad: prose-only documentation with no `iex>` examples.
  # The description is vague ("a string like...") and untestable.
  # A doctest would pin the exact return values and catch regressions.
  @spec format_amount(integer(), atom()) :: String.t()
  def format_amount(cents, currency) when is_integer(cents) and cents >= 0 do
    value = :erlang.float_to_binary(cents / 100, decimals: 2)

    case currency do
      :usd -> "$#{value}"
      :eur -> "€#{value}"
      :gbp -> "£#{value}"
      other -> "#{value} #{other |> Atom.to_string() |> String.upcase()}"
    end
  end

  @doc """
  Generates an invoice reference string.

  The format is "INV-" followed by the customer ID padded to 5 digits,
  a dash, and the sequence number padded to 4 digits.
  Customer IDs and sequence numbers must be positive integers.
  """
  # Bad: describes the format in prose but provides no runnable example.
  # No doctest means the claimed format cannot be verified automatically.
  @spec invoice_ref(pos_integer(), pos_integer()) :: String.t()
  def invoice_ref(customer_id, sequence)
      when is_integer(customer_id) and is_integer(sequence) do
    "INV-#{String.pad_leading(to_string(customer_id), 5, "0")}-#{String.pad_leading(to_string(sequence), 4, "0")}"
  end

  @doc """
  Checks whether an amount is valid for charging.
  Returns true for amounts between 1 and 1,000,000 (inclusive), false otherwise.
  Zero is not a valid charge amount. Amounts above one million are rejected.
  """
  # Bad: no iex> examples. The boundary conditions (0, 1, 1_000_000, 1_000_001)
  # are described in words but never tested via doctest.
  @spec valid_amount?(integer()) :: boolean()
  def valid_amount?(amount) when is_integer(amount) do
    amount in 1..1_000_000
  end
end
