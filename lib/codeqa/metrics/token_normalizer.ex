defmodule CodeQA.Metrics.TokenNormalizer do
  @moduledoc """
  Abstracts raw source code into language-agnostic structural tokens.

  See [lexical analysis](https://en.wikipedia.org/wiki/Lexical_analysis).
  """

  # Note for future: This module can be extended with a second parameter
  # normalize(code, language \\ :agnostic) to load specific regex dictionaries.

  @doc """
  Normalizes source code into a list of structural tokens.

  Replaces string literals with `<STR>`, numeric literals with `<NUM>`,
  and identifiers/keywords with `<ID>`. Remaining punctuation is split into
  individual tokens, with common multi-character operators kept together.

  ## Examples

      iex> CodeQA.Metrics.TokenNormalizer.normalize("x = 42")
      ["<ID>", "=", "<NUM>"]

  """
  @spec normalize(String.t()) :: [String.t()]
  def normalize(code) do
    code
    # 1. Strings (single and double quotes, handling escaped quotes)
    |> String.replace(~r/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/, " <STR> ")
    # 2. Numbers (integers and floats)
    |> String.replace(~r/\b\d+(\.\d+)?\b/, " <NUM> ")
    # 3. Identifiers/Keywords (negative lookbehind/ahead to avoid clobbering <STR>/<NUM>/<ID> tags)
    |> String.replace(~r/(?<!<)\b[a-zA-Z_]\w*\b(?!>)/, " <ID> ")
    # 4. Split by whitespace to extract the tokens and remaining structural punctuation
    |> String.split(~r/\s+/, trim: true)
    # 5. Further split punctuation, keeping common multi-char operators together
    |> Enum.flat_map(&split_punctuation/1)
  end

  defp split_punctuation(token) when token in ["<STR>", "<NUM>", "<ID>"], do: [token]

  defp split_punctuation(text) do
    Regex.scan(~r/->|=>|<>|\|>|::|\.\.\.|<-|!=|==|<=|>=|\+\+|--|&&|\|\||[^\w\s]/, text)
    |> List.flatten()
  end
end
