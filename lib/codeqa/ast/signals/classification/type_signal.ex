defmodule CodeQA.AST.Signals.Classification.TypeSignal do
  @moduledoc """
  Classification signal — votes `:type` when an Elixir type definition
  attribute (`@type`, `@typep`, `@opaque`) appears at indent 0.

  Emits at most one vote. Complements `AttributeSignal`, which handles
  `@spec`, `@doc`, and other attributes.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    @type_attrs MapSet.new(["type", "typep", "opaque"])
    def source(_), do: CodeQA.AST.Signals.Classification.TypeSignal
    def group(_), do: :classification

    def init(_, _lang_mod),
      do: %{at_line_start: true, indent: 0, saw_at: false, is_first: true}

    def emit(_, {_prev, token, _next}, state) do
      case token.kind do
        @nl ->
          {MapSet.new(), %{state | at_line_start: true, indent: 0, saw_at: false}}

        @ws when state.at_line_start ->
          {MapSet.new(), %{state | indent: state.indent + 1, at_line_start: true}}

        @ws ->
          {MapSet.new(), state}

        "@" when state.indent == 0 ->
          {MapSet.new(), %{state | saw_at: true, at_line_start: false}}

        _ when state.saw_at and state.indent == 0 ->
          emit_after_at(token, state)

        _ ->
          {MapSet.new(), %{state | saw_at: false, is_first: false, at_line_start: false}}
      end
    end

    defp emit_after_at(token, state) do
      if MapSet.member?(@type_attrs, token.content) do
        weight = if state.is_first, do: 3, else: 1
        {MapSet.new([{:type_vote, weight}]), :halt}
      else
        {MapSet.new(), %{state | saw_at: false, is_first: false, at_line_start: false}}
      end
    end
  end
end
