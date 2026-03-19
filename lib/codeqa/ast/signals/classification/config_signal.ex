defmodule CodeQA.AST.Signals.Classification.ConfigSignal do
  @moduledoc """
  Classification signal — votes `:config` when a configuration keyword
  appears at indent 0 and bracket depth 0.

  Matches `config` (Elixir Mix.Config), `configure`, `settings`, `options`,
  `defaults`. Emits at most one vote.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    @config_keywords MapSet.new(["config", "configure", "settings", "options", "defaults"])
    def source(_), do: CodeQA.AST.Signals.Classification.ConfigSignal
    def group(_), do: :classification

    def init(_, _lang_mod),
      do: %{at_line_start: true, indent: 0, bracket_depth: 0, is_first: true}

    def emit(_, {_prev, token, _next}, state) do
      %{at_line_start: als, indent: ind, bracket_depth: bd, is_first: first} = state

      case token.kind do
        @nl ->
          {MapSet.new(), %{state | at_line_start: true, indent: 0}}

        @ws when als ->
          {MapSet.new(), %{state | indent: ind + 1, at_line_start: true}}

        @ws ->
          {MapSet.new(), state}

        v when v in ["(", "[", "{"] ->
          {MapSet.new(), %{state | bracket_depth: bd + 1, at_line_start: false, is_first: false}}

        v when v in [")", "]", "}"] ->
          _ = v

          {MapSet.new(),
           %{state | bracket_depth: max(0, bd - 1), at_line_start: false, is_first: false}}

        _ ->
          if ind == 0 and bd == 0 and MapSet.member?(@config_keywords, token.content) do
            weight = if first, do: 3, else: 1
            {MapSet.new([{:config_vote, weight}]), :halt}
          else
            {MapSet.new(), %{state | at_line_start: false, is_first: false}}
          end
      end
    end
  end
end
