defmodule CodeQA.Metrics.SymbolDensity do
  @moduledoc """
  Measures the density of non-word, non-whitespace symbols in source code.

  A high symbol density (brackets, operators, punctuation) relative to total
  characters can indicate dense or hard-to-read expressions.

  See [code readability](https://en.wikipedia.org/wiki/Computer_programming#Readability_of_source_code).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "symbol_density"

  @impl true
  def analyze(%{content: content}) do
    total_chars = String.length(content)

    if total_chars == 0 do
      %{"density" => 0.0, "symbol_count" => 0}
    else
      symbols = Regex.scan(~r/[^\w\s]/u, content)
      symbol_count = length(symbols)

      %{
        "density" => Float.round(symbol_count / total_chars, 4),
        "symbol_count" => symbol_count
      }
    end
  end
end
