defmodule Parser.Good do
  @moduledoc """
  Token parser using full, descriptive variable names.
  GOOD: document, tokens, current_index, accumulator — readable state.
  """

  @spec parse(String.t()) :: {:ok, list()} | {:error, String.t()}
  def parse(document) do
    tokens = tokenize(document)
    parse_tokens(tokens, 0, [])
  end

  defp parse_tokens(tokens, current_index, accumulator) when current_index >= length(tokens) do
    {:ok, Enum.reverse(accumulator)}
  end

  defp parse_tokens(tokens, current_index, accumulator) do
    token = Enum.at(tokens, current_index)
    expression = build_expression(token)

    parse_tokens(tokens, current_index + 1, [expression | accumulator])
  end

  defp build_expression(token) do
    %{type: token.kind, value: token.literal, position: token.offset}
  end

  defp tokenize(document) do
    document
    |> String.split(~r/\s+/, trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {literal, offset} -> %{kind: :word, literal: literal, offset: offset} end)
  end
end
