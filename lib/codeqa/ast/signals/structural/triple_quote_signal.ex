defmodule CodeQA.AST.Signals.Structural.TripleQuoteSignal do
  @moduledoc """
  Emits `:triple_split` at each `<DOC>` token boundary.

  The first of each pair marks the opening of a heredoc; the second marks the
  token after the closing delimiter. These split values are used by the Parser
  to compute protected ranges, preventing other signals' splits from being
  applied inside heredoc content.

  Replaces `ParseRules.TripleQuoteRule`.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @doc_kind CodeQA.AST.Lexing.StringToken.doc_kind()
    def source(_), do: CodeQA.AST.Signals.Structural.TripleQuoteSignal
    def group(_), do: :split

    def init(_, _lang_mod), do: %{idx: 0, inside: false}

    def emit(_, {_, %{kind: @doc_kind}, _}, %{idx: idx, inside: false} = state),
      do: {MapSet.new([{:triple_split, idx}]), %{state | idx: idx + 1, inside: true}}

    def emit(_, {_, %{kind: @doc_kind}, _}, %{idx: idx, inside: true} = state),
      do: {MapSet.new([{:triple_split, idx + 1}]), %{state | idx: idx + 1, inside: false}}

    def emit(_, {_, _, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}
  end
end
