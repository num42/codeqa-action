defmodule CodeQA.Metrics.SymbolDensity do
  @moduledoc """
  Measures the density of non-word, non-whitespace symbols in source code.

  Symbols are characters that are neither word characters (`\\w`: letters, digits,
  underscores) nor whitespace. This includes operators (`+`, `-`, `*`, `/`),
  brackets (`(`, `)`, `[`, `]`, `{`, `}`), and punctuation (`;`, `,`, `.`, etc.).

  A high symbol density relative to total characters can indicate overly dense
  expressions with heavy operator use or deeply nested structures, both of which
  reduce readability.

  Metrics produced:
  - `density` — symbol count divided by total character count, rounded to 4 decimal places
  - `symbol_count` — raw count of symbol characters

  See [code readability](https://en.wikipedia.org/wiki/Computer_programming#Readability_of_source_code).
  """

  @behaviour CodeQA.Metrics.FileMetric

  # Matches any character that is not a word character (\w) or whitespace (\s).
  # The /u flag enables Unicode-aware matching so multi-byte word chars are handled correctly.
  @symbol_pattern ~r/[^\w\s]/u

  @density_precision 4

  @impl true
  def name, do: "symbol_density"

  @impl true
  def analyze(%{content: ""}), do: %{"density" => 0.0, "symbol_count" => 0}

  @impl true
  def analyze(%{content: content}) do
    total_chars = String.length(content)
    symbol_count = count_symbols(content)
    density = compute_density(symbol_count, total_chars)

    %{
      "density" => density,
      "symbol_count" => symbol_count
    }
  end

  defp count_symbols(content) do
    @symbol_pattern
    |> Regex.scan(content)
    |> length()
  end

  defp compute_density(symbol_count, total_chars) do
    Float.round(symbol_count / total_chars, @density_precision)
  end
end
