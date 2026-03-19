defmodule CodeQA.AST.Signals.Classification.DocSignal do
  @moduledoc """
  Classification signal — votes `:doc` when a `<DOC>` (triple-quoted string) token
  is found anywhere in the node's token stream.

  Weight: 3 (unambiguous — triple-quoted strings are documentation).
  Emits at most one vote per token stream.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @doc_kind CodeQA.AST.Lexing.StringToken.doc_kind()
    def source(_), do: CodeQA.AST.Signals.Classification.DocSignal
    def group(_), do: :classification

    def init(_, _lang_mod), do: %{voted: false}

    def emit(_, _, %{voted: true} = state), do: {MapSet.new(), state}

    def emit(_, {_prev, token, _next}, state) do
      if token.kind == @doc_kind do
        {MapSet.new([{:doc_vote, 3}]), %{state | voted: true}}
      else
        {MapSet.new(), state}
      end
    end
  end
end
