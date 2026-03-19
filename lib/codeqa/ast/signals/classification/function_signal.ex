defmodule CodeQA.AST.Signals.Classification.FunctionSignal do
  @moduledoc """
  Classification signal — votes `:function` when a function definition keyword
  appears at indent 0 and bracket depth 0.

  Weights:
  - 3 when it is the first content token of the block (strong match)
  - 1 when found later in the block (weak match, e.g. after a leading comment)

  Does NOT include module/class/namespace keywords (handled by ModuleSignal) or
  test macros like `test`/`describe` (handled by TestSignal).
  Emits at most one vote per token stream.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    def source(_), do: CodeQA.AST.Signals.Classification.FunctionSignal
    def group(_), do: :classification

    def init(_, lang_mod) do
      %{
        at_line_start: true,
        indent: 0,
        bracket_depth: 0,
        is_first: true,
        voted: false,
        keywords: CodeQA.Language.function_keywords(lang_mod)
      }
    end

    def emit(_, _, %{voted: true} = state), do: {MapSet.new(), state}

    def emit(
          _,
          {_prev, token, _next},
          %{at_line_start: als, indent: ind, bracket_depth: bd, is_first: first} = state
        ) do
      case token.kind do
        @nl ->
          {MapSet.new(), %{state | at_line_start: true, indent: 0}}

        @ws when als ->
          {MapSet.new(), %{state | indent: ind + 1, at_line_start: true}}

        @ws ->
          {MapSet.new(), state}

        v when v in ["(", "[", "{"] ->
          {MapSet.new(), %{state | bracket_depth: bd + 1, is_first: false, at_line_start: false}}

        v when v in [")", "]", "}"] ->
          _ = v

          {MapSet.new(),
           %{state | bracket_depth: max(0, bd - 1), is_first: false, at_line_start: false}}

        _ ->
          if ind == 0 and bd == 0 and MapSet.member?(state.keywords, token.content) do
            weight = if first, do: 3, else: 1

            {MapSet.new([{:function_vote, weight}]),
             %{state | is_first: false, at_line_start: false, voted: true}}
          else
            {MapSet.new(), %{state | is_first: false, at_line_start: false}}
          end
      end
    end
  end
end
