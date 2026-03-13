defmodule CodeQA.Metrics.TokenNormalizer do
  @moduledoc """
  Abstracts raw source code into language-agnostic structural tokens.

  See [lexical analysis](https://en.wikipedia.org/wiki/Lexical_analysis).
  """

  # Note for future: This module can be extended with a second parameter
  # normalize(code, language \ :agnostic) to load specific regex dictionaries.

  def normalize(code) do
    code
    # 1. Strings (single and double quotes)
    |> String.replace(~r/".*?"|'.*?'/, " <STR> ")
    # 2. Numbers (integers and floats)
    |> String.replace(~r/\b\d+(\.\d+)?\b/, " <NUM> ")
    # 3. Identifiers/Keywords (any word characters, but negative lookbehind/ahead for angle brackets to not clobber our tags)
    |> String.replace(~r/(?<!<)\b[a-zA-Z_]\w*\b(?!>)/, " <ID> ")
    # 4. Split by whitespace to extract the tokens and remaining structural punctuation
    |> String.split(~r/\s+/, trim: true)
    # 5. Further split punctuation that might be glued together (e.g., `<ID>(<ID>)`)
    |> Enum.flat_map(&split_punctuation/1)
  end

  defp split_punctuation(token) when token in ["<STR>", "<NUM>", "<ID>"], do: [token]

  defp split_punctuation(text) do
    text
    |> String.graphemes()
    |> Enum.reject(&(&1 =~ ~r/\s/))
  end
end
