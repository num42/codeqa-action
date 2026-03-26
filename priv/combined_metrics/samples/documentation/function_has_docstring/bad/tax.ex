defmodule MyApp.Tax do
  @moduledoc """
  Tax calculation context for order totals and line items.
  """

  alias MyApp.Tax.Rate
  alias MyApp.Tax.Exemption
  alias MyApp.Repo

  @spec calculate(Decimal.t(), String.t()) :: Decimal.t()
  def calculate(subtotal, region) do
    rate = fetch_rate(region)
    Decimal.mult(subtotal, rate)
  end

  @spec calculate_line_items([map()], String.t()) :: [map()]
  def calculate_line_items(items, region) do
    rate = fetch_rate(region)
    Enum.map(items, fn item ->
      tax = Decimal.mult(item.price, rate)
      Map.put(item, :tax, tax)
    end)
  end

  @spec effective_rate(String.t()) :: Decimal.t()
  def effective_rate(region) do
    fetch_rate(region)
  end

  @spec exempt?(String.t(), String.t()) :: boolean()
  def exempt?(product_category, region) do
    Repo.get_by(Exemption, category: product_category, region: region) != nil
  end

  @spec apply_exemptions([map()], String.t()) :: [map()]
  def apply_exemptions(items, region) do
    Enum.map(items, fn item ->
      if exempt?(item.category, region) do
        Map.put(item, :tax, Decimal.new(0))
      else
        item
      end
    end)
  end

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

  @spec annual_liability([map()]) :: Decimal.t()
  def annual_liability(transactions) do
    transactions
    |> Enum.map(& &1.tax)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp fetch_rate(region) do
    case Repo.get_by(Rate, region: region) do
      %Rate{rate: rate} -> rate
      nil -> Decimal.new("0.10")
    end
  end
end
