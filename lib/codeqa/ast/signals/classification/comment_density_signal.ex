defmodule CodeQA.AST.Signals.Classification.CommentDensitySignal do
  @moduledoc """
  Classification signal — votes `:comment` when more than 60% of non-blank
  lines begin with a comment prefix.

  Requires `comment_prefixes: [String.t()]` in opts (from the language
  module). Returns no vote if no prefixes are configured.

  Emits at the end of the stream.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @nl CodeQA.AST.Lexing.NewlineToken.kind()
    @ws CodeQA.AST.Lexing.WhitespaceToken.kind()
    def source(_), do: CodeQA.AST.Signals.Classification.CommentDensitySignal
    def group(_), do: :classification

    def init(_, lang_mod) do
      prefixes = MapSet.new(lang_mod.comment_prefixes())
      %{prefixes: prefixes, at_line_start: true, comment_lines: 0, total_lines: 0}
    end

    def emit(_, {_prev, token, next}, state) do
      %{prefixes: prefixes, at_line_start: als} = state

      state =
        case token.kind do
          @nl ->
            %{state | at_line_start: true}

          @ws ->
            state

          _ when als ->
            is_comment = MapSet.member?(prefixes, token.content)

            %{
              state
              | at_line_start: false,
                total_lines: state.total_lines + 1,
                comment_lines: state.comment_lines + if(is_comment, do: 1, else: 0)
            }

          _ ->
            %{state | at_line_start: false}
        end

      maybe_emit_vote(next, prefixes, state)
    end

    defp maybe_emit_vote(nil, prefixes, state)
         when map_size(prefixes) > 0 and state.total_lines > 0 do
      if state.comment_lines / state.total_lines > 0.6 do
        {MapSet.new([{:comment_vote, 2}]), :halt}
      else
        {MapSet.new(), state}
      end
    end

    defp maybe_emit_vote(_next, _prefixes, state), do: {MapSet.new(), state}
  end
end
