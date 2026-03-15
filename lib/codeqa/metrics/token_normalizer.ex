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

  @doc """
  Like normalize/1 but preserves newlines as <NL> and leading whitespace
  as <WS> tokens (one per 2-space / 1-tab indentation unit).
  Used for structural block detection.
  """
  @spec normalize_structural(String.t()) :: [String.t()]
  def normalize_structural(code) do
    code
    |> String.split("\n")
    |> Enum.map(&normalize_structural_line/1)
    |> Enum.intersperse(["<NL>"])
    |> Enum.concat()
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_structural_line(line) do
    indent_units =
      line
      |> String.graphemes()
      |> Enum.take_while(&(&1 in [" ", "\t"]))
      |> Enum.reduce(0, fn "\t", acc -> acc + 2; " ", acc -> acc + 1 end)
      |> div(2)

    ws_tokens = List.duplicate("<WS>", indent_units)

    content_tokens =
      line
      |> String.replace(~r/".*?"|'.*?'/, " <STR> ")
      |> String.replace(~r/\b\d+(\.\d+)?\b/, " <NUM> ")
      |> String.replace(~r/(?<!<)\b[a-zA-Z_]\w*\b(?!>)/, " <ID> ")
      |> String.split(~r/\s+/, trim: true)
      |> Enum.flat_map(&split_punctuation/1)

    ws_tokens ++ content_tokens
  end

  defp split_punctuation(token) when token in ["<STR>", "<NUM>", "<ID>"], do: [token]

  defp split_punctuation(text) do
    text
    |> String.graphemes()
    |> Enum.reject(&(&1 =~ ~r/\s/))
  end
end
