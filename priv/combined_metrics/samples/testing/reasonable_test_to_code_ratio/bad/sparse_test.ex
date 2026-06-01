defmodule Math.CalculatorTest do
  @moduledoc """
  Tests for Calculator — BAD: many public functions but only 1-2 tests.
  The Calculator module has add, subtract, multiply, divide, power, sqrt,
  percentage, and clamp — but almost none are tested.
  """
  use ExUnit.Case

  # Only two tests for a module with 8 public functions

  test "add works" do
    assert Math.Calculator.add(1, 2) == 3
  end

  test "divide" do
    assert Math.Calculator.divide(10, 2) == {:ok, 5.0}
  end

  # subtract/2 — not tested
  # multiply/2 — not tested
  # power/2 — not tested
  # sqrt/1 — not tested
  # percentage/2 — not tested
  # clamp/3 — not tested
end

defmodule Math.Calculator do
  @moduledoc "Simple calculator with multiple public functions."

  @spec add(number(), number()) :: number()
  def add(a, b), do: a + b

  @spec subtract(number(), number()) :: number()
  def subtract(a, b), do: a - b

  @spec multiply(number(), number()) :: number()
  def multiply(a, b), do: a * b

  @spec divide(number(), number()) :: {:ok, float()} | {:error, :division_by_zero}
  def divide(_a, 0), do: {:error, :division_by_zero}
  def divide(a, b), do: {:ok, a / b}

  @spec power(number(), non_neg_integer()) :: number()
  def power(base, exp), do: :math.pow(base, exp)

  @spec sqrt(number()) :: {:ok, float()} | {:error, :negative_input}
  def sqrt(n) when n < 0, do: {:error, :negative_input}
  def sqrt(n), do: {:ok, :math.sqrt(n)}

  @spec percentage(number(), number()) :: float()
  def percentage(value, total) when total != 0, do: value / total * 100.0
  def percentage(_value, 0), do: 0.0

  @spec clamp(number(), number(), number()) :: number()
  def clamp(value, min, max) do
    value |> max(min) |> min(max)
  end
end
