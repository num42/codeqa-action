defmodule CodeQA.AST.Signals.Classification.AttributeSignal do
  @moduledoc """
  Classification signal — votes `:attribute` when an `@identifier` pattern
  appears at indent 0.

  Weights:
  - 3 for Elixir typespec attributes (@spec, @type, @typep, @opaque, @callback, @macrocallback)
  - 2 for all other @name attributes

  Skips @doc and @moduledoc — those nodes contain <DOC> tokens and are handled by DocSignal.
  Emits at most one vote per token stream.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    @typespec_attrs MapSet.new(~w[spec type typep opaque callback macrocallback])
    @skip_attrs MapSet.new(~w[doc moduledoc])

    def source(_), do: CodeQA.AST.Signals.Classification.AttributeSignal
    def group(_), do: :classification

    def init(_, _lang_mod),
      do: %{at_line_start: true, indent: 0, saw_at: false, voted: false}

    def emit(_, _, %{voted: true} = state), do: {MapSet.new(), state}

    def emit(_, {_prev, token, _next}, %{at_line_start: als, indent: ind, saw_at: saw_at} = state) do
      case token.kind do
        @nl ->
          {MapSet.new(), %{state | at_line_start: true, indent: 0, saw_at: false}}

        @ws when als ->
          {MapSet.new(), %{state | indent: ind + 1, at_line_start: true}}

        @ws ->
          {MapSet.new(), state}

        "@" when ind == 0 ->
          {MapSet.new(), %{state | saw_at: true, at_line_start: false}}

        "<ID>" when saw_at ->
          emit_attribute(token.content, state)

        _ ->
          {MapSet.new(), %{state | saw_at: false, at_line_start: false}}
      end
    end

    defp emit_attribute(name, state) do
      base_state = %{state | saw_at: false, at_line_start: false, voted: true}

      cond do
        MapSet.member?(@skip_attrs, name) ->
          # @doc/@moduledoc: let DocSignal handle via <DOC> tokens
          {MapSet.new(), base_state}

        MapSet.member?(@typespec_attrs, name) ->
          {MapSet.new([{:attribute_vote, 3}]), base_state}

        true ->
          {MapSet.new([{:attribute_vote, 2}]), base_state}
      end
    end
  end
end
