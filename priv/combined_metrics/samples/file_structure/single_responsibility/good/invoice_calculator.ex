defmodule InvoiceCalculator do
  @moduledoc """
  Computes invoice totals only: line items, discounts, tax.

  Rendering, persistence and delivery live in their own modules and are
  invoked by the caller after the total is computed.
  """

  @spec total(map()) :: map()
  def total(invoice) do
    subtotal = subtotal(invoice.line_items)
    discount = discount(subtotal, invoice.coupon)
    taxable = subtotal - discount
    tax = tax(taxable, invoice.region)

    %{subtotal: subtotal, discount: discount, tax: tax, total: taxable + tax}
  end

  @spec subtotal(list()) :: integer()
  def subtotal(line_items) do
    Enum.reduce(line_items, 0, fn item, acc -> acc + item.unit_price * item.quantity end)
  end

  @spec discount(integer(), map() | nil) :: integer()
  def discount(_subtotal, nil), do: 0
  def discount(subtotal, %{type: :percent, value: value}), do: div(subtotal * value, 100)
  def discount(_subtotal, %{type: :flat, value: value}), do: value

  @spec tax(integer(), atom()) :: integer()
  def tax(amount, region) do
    rate = tax_rate(region)
    div(amount * rate, 100)
  end

  defp tax_rate(:eu), do: 19
  defp tax_rate(:us), do: 8
  defp tax_rate(_), do: 0
end
