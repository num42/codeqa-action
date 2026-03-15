defmodule Calculator.Bad do
  @moduledoc """
  Pricing and discount calculator with single-letter variable names.
  BAD: function params and local vars named x, y, z, a, b, n, m lose all meaning.
  """

  @spec apply_discount(number(), number()) :: number()
  def apply_discount(x, y) do
    z = x * (1 - y / 100)
    Float.round(z, 2)
  end

  @spec calculate_total(list(), number()) :: number()
  def calculate_total(a, b) do
    n = Enum.reduce(a, 0, fn x, acc -> acc + x end)
    m = n * (1 + b / 100)
    Float.round(m, 2)
  end

  @spec tiered_price(number(), list()) :: number()
  def tiered_price(x, y) do
    Enum.reduce_while(y, x, fn {a, b}, acc ->
      if acc > a do
        {:cont, acc * (1 - b / 100)}
      else
        {:halt, acc}
      end
    end)
  end

  @spec split_payment(number(), integer()) :: list(number())
  def split_payment(a, n) do
    b = Float.round(a / n, 2)
    m = a - b * (n - 1)
    List.duplicate(b, n - 1) ++ [Float.round(m, 2)]
  end

  @spec compound_discount(number(), list()) :: number()
  def compound_discount(x, y) do
    Enum.reduce(y, x, fn a, b ->
      b * (1 - a / 100)
    end)
    |> Float.round(2)
  end

  @spec price_with_tax(number(), number(), number()) :: map()
  def price_with_tax(x, y, z) do
    a = x * y
    b = a * z / 100
    %{
      subtotal: Float.round(a, 2),
      tax: Float.round(b, 2),
      total: Float.round(a + b, 2)
    }
  end

  @spec bulk_pricing(number(), integer(), integer()) :: number()
  def bulk_pricing(x, n, m) do
    cond do
      n >= m -> x * 0.75
      n >= div(m, 2) -> x * 0.9
      true -> x
    end
    |> Float.round(2)
  end

  @spec margin(number(), number()) :: number()
  def margin(x, y) do
    z = (x - y) / x * 100
    Float.round(z, 2)
  end
end
