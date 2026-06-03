defmodule Invoice.Bad do
  @moduledoc """
  Invoice calculation with type suffixes in variable names.
  BAD: variables include redundant type suffixes like _list, _string, _integer, _keyword.
  """

  @spec build(map(), keyword()) :: map()
  def build(customer_map, opts_keyword) do
    line_list = Keyword.get(opts_keyword, :lines, [])
    currency_string = Keyword.get(opts_keyword, :currency, "EUR")
    discount_integer = Keyword.get(opts_keyword, :discount, 0)

    subtotal_integer = Enum.reduce(line_list, 0, fn line, sum -> sum + line.price * line.qty end)
    reduction_integer = round(subtotal_integer * discount_integer / 100)
    tax_integer = round((subtotal_integer - reduction_integer) * 0.19)
    total_integer = subtotal_integer - reduction_integer + tax_integer

    number_string = generate_number_string(customer_map.id)

    %{
      number: number_string,
      customer: customer_map.name,
      currency: currency_string,
      subtotal: subtotal_integer,
      tax: tax_integer,
      total: total_integer
    }
  end

  @spec overdue?(map(), Date.t()) :: boolean()
  def overdue?(invoice_map, today_date) do
    Date.compare(invoice_map.due_date, today_date) == :lt
  end

  defp generate_number_string(id), do: "INV-#{id}-#{System.unique_integer([:positive])}"
end
