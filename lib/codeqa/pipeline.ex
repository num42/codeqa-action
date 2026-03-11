defmodule CodeQA.Pipeline do
  @moduledoc "Pre-computed shared context for file-level metrics."

  defmodule FileContext do
    @moduledoc "Immutable pre-computed data shared across all file metrics."
    @enforce_keys [:content, :tokens, :token_counts, :words, :identifiers,
                   :lines, :encoded, :byte_count, :line_count]
    defstruct @enforce_keys
  end

  @word_re ~r/\b[a-zA-Z_]\w*\b/u

  @keywords MapSet.new(~w[
    if else elif for while return import from class def and or not in is
    None True False try except finally with as raise pass yield break
    continue lambda del global nonlocal assert var let const function new
    this typeof instanceof void null undefined async await static public
    private protected interface type enum struct match case switch default
    do goto throw throws catch final abstract extends implements package
    int float double long short byte char boolean string bool fn pub mod
    use crate impl trait where self Self super mut ref move
  ])

  @spec build_file_context(String.t(), keyword()) :: FileContext.t()
  def build_file_context(content, opts \\ []) when is_binary(content) do
    stopwords = Keyword.get(opts, :word_stopwords, MapSet.new())

    tokens = content |> String.split() |> List.to_tuple()
    token_list = Tuple.to_list(tokens)
    token_counts = Enum.frequencies(token_list)
    words = 
      Regex.scan(@word_re, content) 
      |> List.flatten() 
      |> Enum.reject(&MapSet.member?(stopwords, &1))
      |> List.to_tuple()
    word_list = Tuple.to_list(words)
    identifiers = word_list |> Enum.reject(&MapSet.member?(@keywords, &1)) |> List.to_tuple()
    lines = content |> String.split("\n") |> trim_trailing_empty() |> List.to_tuple()
    encoded = content

    %FileContext{
      content: content,
      tokens: tokens,
      token_counts: token_counts,
      words: words,
      identifiers: identifiers,
      lines: lines,
      encoded: encoded,
      byte_count: byte_size(content),
      line_count: tuple_size(lines)
    }
  end

  defp trim_trailing_empty(lines) do
    # Match Python's str.splitlines() behavior
    case List.last(lines) do
      "" -> List.delete_at(lines, -1)
      _ -> lines
    end
  end
end
