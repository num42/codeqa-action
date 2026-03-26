defmodule Math.CalculatorTest do
  @moduledoc """
  Tests for Calculator — GOOD: multiple test cases per public function.
  """
  use ExUnit.Case

  describe "add/2" do
    test "sums two positive integers" do
      assert Math.Calculator.add(2, 3) == 5
    end

    test "handles negative numbers" do
      assert Math.Calculator.add(-1, 1) == 0
    end
  end

  describe "subtract/2" do
    test "subtracts second from first" do
      assert Math.Calculator.subtract(10, 4) == 6
    end

    test "returns negative when second is larger" do
      assert Math.Calculator.subtract(3, 7) == -4
    end
  end

  describe "divide/2" do
    test "returns {:ok, float} for valid division" do
      assert Math.Calculator.divide(10, 4) == {:ok, 2.5}
    end

    test "returns {:error, :division_by_zero} when divisor is zero" do
      assert Math.Calculator.divide(5, 0) == {:error, :division_by_zero}
    end
  end

  describe "sqrt/1" do
    test "returns {:ok, float} for positive input" do
      assert Math.Calculator.sqrt(9) == {:ok, 3.0}
    end

    test "returns {:error, :negative_input} for negative number" do
      assert Math.Calculator.sqrt(-4) == {:error, :negative_input}
    end

    test "returns {:ok, 0.0} for zero" do
      assert Math.Calculator.sqrt(0) == {:ok, 0.0}
    end
  end

  describe "percentage/2" do
    test "calculates percentage of total" do
      assert Math.Calculator.percentage(25, 200) == 12.5
    end

    test "returns 0.0 when total is zero" do
      assert Math.Calculator.percentage(10, 0) == 0.0
    end
  end

  describe "clamp/3" do
    test "returns value when within range" do
      assert Math.Calculator.clamp(5, 1, 10) == 5
    end

    test "returns min when value is below range" do
      assert Math.Calculator.clamp(-3, 0, 100) == 0
    end

    test "returns max when value is above range" do
      assert Math.Calculator.clamp(200, 0, 100) == 100
    end
  end
end

defmodule Math.Calculator do
  @spec add(number(), number()) :: number()
  def add(a, b), do: a + b

  @spec subtract(number(), number()) :: number()
  def subtract(a, b), do: a - b

  @spec multiply(number(), number()) :: number()
  def multiply(a, b), do: a * b

  @spec divide(number(), number()) :: {:ok, float()} | {:error, :division_by_zero}
  def divide(_a, 0), do: {:error, :division_by_zero}
  def divide(a, b), do: {:ok, a / b}

  @spec sqrt(number()) :: {:ok, float()} | {:error, :negative_input}
  def sqrt(n) when n < 0, do: {:error, :negative_input}
  def sqrt(n), do: {:ok, :math.sqrt(n)}

  @spec percentage(number(), number()) :: float()
  def percentage(_value, 0), do: 0.0
  def percentage(value, total), do: value / total * 100.0

  @spec clamp(number(), number(), number()) :: number()
  def clamp(value, min, max), do: value |> max(min) |> min(max)
end
