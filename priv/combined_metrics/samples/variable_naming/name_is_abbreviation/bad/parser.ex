defmodule Parser.Bad do
  @moduledoc """
  Token parser using abbreviated variable names.
  BAD: doc, toks, idx, acc, tok, expr, lit, pos obscure the parsing state.
  """

  @spec parse(String.t()) :: {:ok, list()} | {:error, String.t()}
  def parse(doc) do
    toks = tokenize(doc)
    parse_toks(toks, 0, [])
  end

  defp parse_toks(toks, idx, acc) when idx >= length(toks) do
    {:ok, Enum.reverse(acc)}
  end

  defp parse_toks(toks, idx, acc) do
    tok = Enum.at(toks, idx)
    expr = build_expr(tok)

    parse_toks(toks, idx + 1, [expr | acc])
  end

  defp build_expr(tok) do
    %{type: tok.knd, value: tok.lit, position: tok.pos}
  end

  defp tokenize(doc) do
    doc
    |> String.split(~r/\s+/, trim: true)
    |> Enum.with_index()
    |> Enum.map(fn {lit, pos} -> %{knd: :word, lit: lit, pos: pos} end)
  end
end
