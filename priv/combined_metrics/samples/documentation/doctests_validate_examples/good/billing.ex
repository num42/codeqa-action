defmodule MyApp.Billing.Formatter do
  @moduledoc """
  Formatting utilities for billing amounts and invoice references.

  All examples in this module's `@doc` blocks are run as ExUnit doctests.
  See `test/my_app/billing/formatter_test.exs`.
  """

  @doc """
  Formats an integer amount in cents to a display string for the given currency.

      iex> MyApp.Billing.Formatter.format_amount(2999, :usd)
      "$29.99"

      iex> MyApp.Billing.Formatter.format_amount(1050, :eur)
      "€10.50"

      iex> MyApp.Billing.Formatter.format_amount(0, :gbp)
      "£0.00"

      iex> MyApp.Billing.Formatter.format_amount(100, :unknown)
      "1.00 UNKNOWN"
  """
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
  Generates an invoice reference from a customer ID and sequence number.

      iex> MyApp.Billing.Formatter.invoice_ref(42, 7)
      "INV-00042-0007"

      iex> MyApp.Billing.Formatter.invoice_ref(1, 1)
      "INV-00001-0001"

      iex> MyApp.Billing.Formatter.invoice_ref(99999, 9999)
      "INV-99999-9999"
  """
  @spec invoice_ref(pos_integer(), pos_integer()) :: String.t()
  def invoice_ref(customer_id, sequence)
      when is_integer(customer_id) and is_integer(sequence) do
    "INV-#{String.pad_leading(to_string(customer_id), 5, "0")}-#{String.pad_leading(to_string(sequence), 4, "0")}"
  end

  @doc """
  Returns true if the amount is within the acceptable charge range.

      iex> MyApp.Billing.Formatter.valid_amount?(50)
      true

      iex> MyApp.Billing.Formatter.valid_amount?(0)
      false

      iex> MyApp.Billing.Formatter.valid_amount?(10_000_00)
      true

      iex> MyApp.Billing.Formatter.valid_amount?(10_000_01)
      false
  """
  @spec valid_amount?(integer()) :: boolean()
  def valid_amount?(amount) when is_integer(amount) do
    amount in 1..1_000_000
  end
end
