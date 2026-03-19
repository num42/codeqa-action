defmodule CodeQA.AST.Signals.Structural.CommentDividerSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:comment_divider_split` when a line is a "visual divider" comment —
  a comment prefix at line start followed immediately by repetitive non-word
  punctuation characters.

  Used to detect section separators like `# ---`, `// ===`, `-- ---`.
  No split is emitted for the first such line (seen_content must be true).

  When `opts[:language_module]` is set, uses that language's
  `comment_prefixes/0` callback.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.CommentDividerSignal
    def group(_), do: :split

    def init(_, lang_mod) do
      comment_prefixes = MapSet.new(lang_mod.comment_prefixes())
      divider_indicators = CodeQA.Language.divider_indicators(lang_mod)

      %{
        idx: 0,
        at_line_start: true,
        seen_content: false,
        indent: 0,
        comment_prefixes: comment_prefixes,
        divider_indicators: divider_indicators
      }
    end

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true, indent: 0}}

    def emit(
          _,
          {_, %WhitespaceToken{}, _},
          %{idx: idx, at_line_start: true, indent: indent} = state
        ),
        do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true, indent: indent + 1}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, token, next}, %{idx: idx} = state) do
      base = %{state | idx: idx + 1, at_line_start: false, seen_content: true}

      emissions =
        if divider_split?(state, token, next),
          do: MapSet.new([{:comment_divider_split, idx}]),
          else: MapSet.new()

      {emissions, base}
    end

    defp divider_split?(
           %{
             seen_content: true,
             at_line_start: true,
             indent: 0,
             comment_prefixes: cp,
             divider_indicators: di
           },
           %{kind: k},
           next
         ),
         do: MapSet.member?(cp, k) and next != nil and MapSet.member?(di, next.kind)

    defp divider_split?(_, _, _), do: false
  end
end
