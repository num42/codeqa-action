defmodule CodeQA.AST.Signals.Structural.KeywordSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:keyword_split` when a declaration keyword appears at bracket depth 0
  and indentation level 0.

  When `opts[:language_module]` is set, uses that language's
  `declaration_keywords/0` callback.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.KeywordSignal
    def group(_), do: :split

    def init(_, lang_mod) do
      keywords = CodeQA.Language.declaration_keywords(lang_mod)

      %{
        idx: 0,
        bracket_depth: 0,
        indent: 0,
        at_line_start: true,
        seen_content: false,
        keywords: keywords
      }
    end

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, indent: 0, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx, indent: i, at_line_start: true} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, indent: i + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, %{kind: k}, _}, %{idx: idx, bracket_depth: bd} = state)
        when k in ["(", "[", "{"],
        do:
          {MapSet.new(),
           %{
             state
             | idx: idx + 1,
               bracket_depth: bd + 1,
               seen_content: true,
               at_line_start: false
           }}

    def emit(_, {_, %{kind: k}, _}, %{idx: idx, bracket_depth: bd} = state)
        when k in [")", "]", "}"],
        do:
          {MapSet.new(),
           %{
             state
             | idx: idx + 1,
               bracket_depth: max(0, bd - 1),
               seen_content: true,
               at_line_start: false
           }}

    def emit(_, {_, token, _}, %{idx: idx} = state) do
      base = %{state | idx: idx + 1, seen_content: true, at_line_start: false}

      emissions =
        if keyword_split?(state, token),
          do: MapSet.new([{:keyword_split, idx}]),
          else: MapSet.new()

      {emissions, base}
    end

    defp keyword_split?(%{seen_content: true, bracket_depth: 0, indent: 0, keywords: kw}, %{
           content: c
         }),
         do: MapSet.member?(kw, c)

    defp keyword_split?(_, _), do: false
  end
end
