defmodule MyApp.Tax do
  @moduledoc """
  Tax calculation context for order totals and line items.
  """

  alias MyApp.Tax.Rate
  alias MyApp.Tax.Exemption
  alias MyApp.Repo

  @doc """
  Calculates the tax amount for a given subtotal and region.

  Returns the tax amount as a `Decimal`, not the total. Use `summarize/2`
  to get a full breakdown including subtotal, tax, and total.

  ## Examples

      iex> MyApp.Tax.calculate(Decimal.new("100.00"), "us-ca")
      Decimal.new("8.25")
  """
  @spec calculate(Decimal.t(), String.t()) :: Decimal.t()
  def calculate(subtotal, region) do
    rate = fetch_rate(region)
    Decimal.mult(subtotal, rate)
  end

  @doc """
  Applies per-line-item tax to a list of order items for a given region.

  Each item map must have a `:price` and `:category` key. Returns the
  same list with a `:tax` key added to each item. Items with an exemption
  in the given region receive a tax of zero.
  """
  @spec calculate_line_items([map()], String.t()) :: [map()]
  def calculate_line_items(items, region) do
    items
    |> apply_exemptions(region)
    |> Enum.map(&apply_tax_rate(&1, fetch_rate(region)))
  end

  @doc """
  Returns the applicable tax rate for the given region as a `Decimal`.

  Falls back to a default rate of 10% when no specific rate is configured.
  """
  @spec effective_rate(String.t()) :: Decimal.t()
  def effective_rate(region) do
    fetch_rate(region)
  end

  @doc """
  Returns `true` if the given product category is tax-exempt in a region.
  """
  @spec exempt?(String.t(), String.t()) :: boolean()
  def exempt?(product_category, region) do
    Repo.get_by(Exemption, category: product_category, region: region) != nil
  end

  @doc """
  Returns a tax summary map for a subtotal and region.

  The map contains `:subtotal`, `:tax`, `:total`, `:rate`, and `:region`.
  """
  @spec summarize(Decimal.t(), String.t()) :: map()
  def summarize(subtotal, region) do
    tax = calculate(subtotal, region)
    total = Decimal.add(subtotal, tax)

    %{
      subtotal: subtotal,
      tax: tax,
      total: total,
      rate: effective_rate(region),
      region: region
    }
  end

  @doc """
  Sums the total tax liability across a list of transactions.

  Each transaction map must have a `:tax` key with a `Decimal` value.
  """
  @spec annual_liability([map()]) :: Decimal.t()
  def annual_liability(transactions) do
    transactions
    |> Enum.map(& &1.tax)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp apply_exemptions(items, region) do
    Enum.map(items, fn item ->
      if exempt?(item.category, region), do: Map.put(item, :tax, Decimal.new(0)), else: item
    end)
  end

  defp apply_tax_rate(%{tax: _already_set} = item, _rate), do: item
  defp apply_tax_rate(item, rate), do: Map.put(item, :tax, Decimal.mult(item.price, rate))

  defp fetch_rate(region) do
    case Repo.get_by(Rate, region: region) do
      %Rate{rate: rate} -> rate
      nil -> Decimal.new("0.10")
    end
  end
end
