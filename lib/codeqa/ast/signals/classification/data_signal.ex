defmodule CodeQA.AST.Signals.Classification.DataSignal do
  @moduledoc """
  Classification signal — votes `:data` when a token stream consists primarily
  of literal values (`<STR>`, `<NUM>`) with no control-flow keywords.

  Emits at the end of the stream (when `next == nil`). Votes only when
  literal ratio > 0.6 and no control-flow keywords were seen.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @str CodeQA.AST.Lexing.StringToken.kind()
    @control_flow MapSet.new([
                    "if",
                    "else",
                    "elsif",
                    "elif",
                    "unless",
                    "for",
                    "while",
                    "do",
                    "case",
                    "when",
                    "cond",
                    "switch",
                    "loop",
                    "until"
                  ])
    def source(_), do: CodeQA.AST.Signals.Classification.DataSignal
    def group(_), do: :classification

    def init(_, _lang_mod),
      do: %{literal_count: 0, id_count: 0, has_control_flow: false}

    def emit(_, {_prev, token, next}, state) do
      state =
        case token.kind do
          kind when kind in [@str, "<NUM>"] ->
            %{state | literal_count: state.literal_count + 1}

          "<ID>" ->
            if MapSet.member?(@control_flow, token.content) do
              %{state | has_control_flow: true, id_count: state.id_count + 1}
            else
              %{state | id_count: state.id_count + 1}
            end

          _ ->
            state
        end

      if next == nil do
        total = state.literal_count + state.id_count

        if total > 0 and not state.has_control_flow and
             state.literal_count / total > 0.6 do
          {MapSet.new([{:data_vote, 2}]), :halt}
        else
          {MapSet.new(), state}
        end
      else
        {MapSet.new(), state}
      end
    end
  end
end
