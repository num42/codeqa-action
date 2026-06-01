defmodule Test.Fixtures.Elixir.Calculator do
  @moduledoc false
  use Test.LanguageFixture, language: "elixir calculator"
  import Test.NodeMatcher

  @code ~S'''
  defmodule Calculator.Behaviour do
    @moduledoc "Contract for all calculator implementations."
    @callback add(number, number) :: number
    @callback subtract(number, number) :: number
    @callback multiply(number, number) :: number
    @callback divide(number, number) :: {:ok, float} | {:error, :division_by_zero}
  end

  defprotocol Calculator.Displayable do
    @doc "Converts a result to a human-readable string."
    def display(value)
  end

  defmodule Calculator.Basic do
    @moduledoc "Basic arithmetic calculator."
    @behaviour Calculator.Behaviour

    @doc "Adds two numbers."
    @spec add(number, number) :: number
    def add(a, b), do: a + b

    @doc "Subtracts b from a."
    @spec subtract(number, number) :: number
    def subtract(a, b), do: a - b

    @doc "Multiplies two numbers."
    @spec multiply(number, number) :: number
    def multiply(a, b), do: a * b

    @doc "Divides a by b, returns error for zero divisor."
    @spec divide(number, number) :: {:ok, float} | {:error, :division_by_zero}
    def divide(_a, 0), do: {:error, :division_by_zero}
    def divide(a, b), do: {:ok, a / b}

    @doc "Absolute value of n."
    @spec abs_val(number) :: number
    def abs_val(n) when n < 0, do: -n
    def abs_val(n), do: n
  end

  defimpl Calculator.Displayable, for: Integer do
    def display(value), do: Integer.to_string(value)
  end

  defimpl Calculator.Displayable, for: Float do
    def display(value), do: :erlang.float_to_binary(value, [decimals: 4])
  end

  defmodule Calculator.Scientific do
    @moduledoc "Scientific calculator with extended math operations."
    @behaviour Calculator.Behaviour

    @doc "Adds two numbers."
    @spec add(number, number) :: number
    def add(a, b), do: a + b

    @doc "Subtracts b from a."
    @spec subtract(number, number) :: number
    def subtract(a, b), do: a - b

    @doc "Multiplies two numbers."
    @spec multiply(number, number) :: number
    def multiply(a, b), do: a * b

    @doc "Divides, returning an error on zero divisor."
    @spec divide(number, number) :: {:ok, float} | {:error, :division_by_zero}
    def divide(_a, 0), do: {:error, :division_by_zero}
    def divide(a, b), do: {:ok, a / b}

    @doc "Raises a to the power of b."
    @spec power(number, number) :: number
    def power(a, b), do: :math.pow(a, b)

    @doc "Returns the square root or an error for negative input."
    @spec sqrt(number) :: {:ok, float} | {:error, :negative_input}
    def sqrt(n) when n < 0, do: {:error, :negative_input}
    def sqrt(n), do: {:ok, :math.sqrt(n)}

    @doc "Natural logarithm, error for non-positive input."
    @spec log(number) :: {:ok, float} | {:error, :non_positive_input}
    def log(n) when n <= 0, do: {:error, :non_positive_input}
    def log(n), do: {:ok, :math.log(n)}

    defp validate_positive(n) when n > 0, do: {:ok, n}
    defp validate_positive(_n), do: {:error, :non_positive_input}
  end

  defmodule Calculator.History do
    @moduledoc "Tracks a history of calculator operations."
    @type entry :: {atom, list}
    @type t :: list

    @doc "Creates an empty history."
    @spec new() :: t
    def new(), do: []

    @doc "Records an operation entry."
    @spec record(t, atom, list) :: t
    def record(history, op, args) when is_list(args), do: [{op, args} | history]

    @doc "Returns the last n entries."
    @spec last(t, non_neg_integer) :: t
    def last(history, n \\ 5), do: Enum.take(history, n)

    @doc "Clears the history."
    @spec clear(t) :: t
    def clear(_history), do: []

    defp format_entry({op, args}), do: "#{op}(#{Enum.join(args, ", ")})"
  end
  '''

  @block_assertions [
    %{
      description: "a compound block containing add with doc and spec annotations",
      all_of: [exact(:content, "add"), exact(:content, "doc"), exact(:content, "spec")]
    }
  ]
end
