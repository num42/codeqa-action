defmodule Invoice.Good do
  @moduledoc """
  Invoice calculation without type suffixes in variable names.
  GOOD: variable names express what the data is, not what type it has.
  """

  @spec build(map(), keyword()) :: map()
  def build(customer, opts) do
    lines = Keyword.get(opts, :lines, [])
    currency = Keyword.get(opts, :currency, "EUR")
    discount = Keyword.get(opts, :discount, 0)

    subtotal = Enum.reduce(lines, 0, fn line, sum -> sum + line.price * line.qty end)
    reduction = round(subtotal * discount / 100)
    tax = round((subtotal - reduction) * 0.19)
    total = subtotal - reduction + tax

    number = generate_number(customer.id)

    %{
      number: number,
      customer: customer.name,
      currency: currency,
      subtotal: subtotal,
      tax: tax,
      total: total
    }
  end

  @spec overdue?(map(), Date.t()) :: boolean()
  def overdue?(invoice, today) do
    Date.compare(invoice.due_date, today) == :lt
  end

  defp generate_number(id), do: "INV-#{id}-#{System.unique_integer([:positive])}"
end
