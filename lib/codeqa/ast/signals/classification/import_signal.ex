defmodule CodeQA.AST.Signals.Classification.ImportSignal do
  @moduledoc """
  Classification signal — votes `:import` when an import/require/use/alias keyword
  appears at indent 0.

  Weights:
  - 3 when it is the first content token of the block (strong match)
  - 1 when found later in the block

  Covers: Elixir (import, require, use, alias), Python (import, from),
  JavaScript/Go (import, package), C# (using), Ruby/Lua (require, include).
  Emits at most one vote per token stream.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    def source(_), do: CodeQA.AST.Signals.Classification.ImportSignal
    def group(_), do: :classification

    def init(_, lang_mod) do
      %{
        at_line_start: true,
        indent: 0,
        is_first: true,
        voted: false,
        keywords: CodeQA.Language.import_keywords(lang_mod)
      }
    end

    def emit(_, _, %{voted: true} = state), do: {MapSet.new(), state}

    def emit(
          _,
          {_prev, token, _next},
          %{at_line_start: als, indent: ind, is_first: first} = state
        ) do
      case token.kind do
        @nl ->
          {MapSet.new(), %{state | at_line_start: true, indent: 0}}

        @ws when als ->
          {MapSet.new(), %{state | indent: ind + 1, at_line_start: true}}

        @ws ->
          {MapSet.new(), state}

        _ ->
          emit_content_token(token, state, ind, first)
      end
    end

    defp emit_content_token(token, state, ind, first) do
      base_state = %{state | is_first: false, at_line_start: false}

      if ind == 0 and MapSet.member?(state.keywords, token.content) do
        weight = if first, do: 3, else: 1
        {MapSet.new([{:import_vote, weight}]), %{base_state | voted: true}}
      else
        {MapSet.new(), base_state}
      end
    end
  end
end
