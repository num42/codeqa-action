defmodule CodeQA.AST.Signals.Structural.AccessModifierSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:access_modifier_split` when an access modifier keyword appears at line
  start with bracket_depth == 0.

  Unlike `KeywordSignal`, this does NOT require indentation level 0, so it
  detects class members inside bracket enclosures (e.g. `public void foo()` inside
  a `class Foo { ... }` body).

  When `opts[:language_module]` is set, uses that language's
  `access_modifiers/0` callback.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.AccessModifierSignal
    def group(_), do: :split

    def init(_, lang_mod) do
      modifiers = CodeQA.Language.access_modifiers(lang_mod)
      %{idx: 0, bracket_depth: 0, at_line_start: true, seen_content: false, modifiers: modifiers}
    end

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx, at_line_start: true} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, at_line_start: true}}

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
        if modifier_split?(state, token),
          do: MapSet.new([{:access_modifier_split, idx}]),
          else: MapSet.new()

      {emissions, base}
    end

    defp modifier_split?(
           %{seen_content: true, bracket_depth: 0, at_line_start: true, modifiers: m},
           %{content: c}
         ),
         do: MapSet.member?(m, c)

    defp modifier_split?(_, _), do: false
  end
end
