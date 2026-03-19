defmodule CodeQA.AST.Signals.Classification.TestSignal do
  @moduledoc """
  Classification signal — votes `:test` when a test block keyword appears at
  indent 0.

  Weights:
  - 3 when it is the first content token of the block (strong match)
  - 1 when found later in the block

  Covers: ExUnit (test, describe), RSpec/Jest/Mocha (it, context, describe),
  Cucumber (scenario, given, feature). `test` takes priority over
  FunctionSignal — Elixir test macros look like function calls but are test blocks.
  Emits at most one vote per token stream.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    def source(_), do: CodeQA.AST.Signals.Classification.TestSignal
    def group(_), do: :classification

    def init(_, lang_mod) do
      %{
        at_line_start: true,
        indent: 0,
        is_first: true,
        voted: false,
        keywords: CodeQA.Language.test_keywords(lang_mod)
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
          if ind == 0 and MapSet.member?(state.keywords, token.content) do
            weight = if first, do: 3, else: 1

            {MapSet.new([{:test_vote, weight}]),
             %{state | is_first: false, at_line_start: false, voted: true}}
          else
            {MapSet.new(), %{state | is_first: false, at_line_start: false}}
          end
      end
    end
  end
end
