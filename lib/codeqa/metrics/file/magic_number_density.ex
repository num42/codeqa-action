defmodule CodeQA.Metrics.File.MagicNumberDensity do
  @moduledoc """
  Measures the density of magic numbers and string literals in source code.

  Counts numeric literals (excluding common constants 0, 1, 0.0, 1.0) and
  double-quoted string literals as proportions of total tokens. High densities
  suggest unexplained constants or hardcoded values that should be extracted.

  Note: negative numbers (e.g. `-42`) are not detected since the minus sign
  is a separate token.

  See [magic number](<https://en.wikipedia.org/wiki/Magic_number_(programming)>).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "magic_number_density"

  @impl true
  def keys, do: ["density", "magic_number_count", "string_literal_ratio"]

  @number_re ~r/\b\d+\.?\d*(?:[eE][+-]?\d+)?\b/
  @idiomatic_constants ~w[0 1 2 0.0 1.0 0.5]
  @string_literal_re ~r/"(?:[^"\\]|\\.)*"/

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: content, tokens: tokens}) do
    total_tokens = length(tokens)

    if total_tokens == 0 do
      %{"density" => 0.0, "magic_number_count" => 0, "string_literal_ratio" => 0.0}
    else
      numbers =
        @number_re
        |> Regex.scan(content)
        |> List.flatten()
        |> Enum.reject(&(&1 in @idiomatic_constants))

      magic_count = length(numbers)
      string_count = @string_literal_re |> Regex.scan(content) |> length()

      %{
        "density" => Float.round(magic_count / total_tokens, 4),
        "magic_number_count" => magic_count,
        "string_literal_ratio" => Float.round(string_count / total_tokens, 4)
      }
    end
  end
end
