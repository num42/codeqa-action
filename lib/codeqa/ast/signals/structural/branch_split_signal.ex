defmodule CodeQA.AST.Signals.Structural.BranchSplitSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken
  alias CodeQA.Language

  @moduledoc """
  Emits `:branch_split` when a branch keyword appears at bracket depth 0
  and at least one token has been seen before it.

  Unlike `KeywordSignal`, there is no indentation constraint — branches inside
  functions are intentionally split into sibling child blocks by the parser's
  recursive phase.

  When `opts[:language_module]` is set, uses that language's
  `branch_keywords/0` callback.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.BranchSplitSignal
    def group(_), do: :branch_split

    def init(_, lang_mod) do
      keywords = Language.branch_keywords(lang_mod)
      %{bracket_depth: 0, idx: 0, keywords: keywords, seen_content: false}
    end

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, %{kind: k}, _}, %{bracket_depth: bd, idx: idx} = state)
        when k in ["(", "[", "{"],
        do: {MapSet.new(), %{state | idx: idx + 1, bracket_depth: bd + 1, seen_content: true}}

    def emit(_, {_, %{kind: k}, _}, %{bracket_depth: bd, idx: idx} = state)
        when k in [")", "]", "}"],
        do:
          {MapSet.new(),
           %{state | idx: idx + 1, bracket_depth: max(0, bd - 1), seen_content: true}}

    def emit(_, {_, token, _}, %{idx: idx} = state) do
      base = %{state | idx: idx + 1, seen_content: true}

      emissions =
        if branch_split?(state, token), do: MapSet.new([{:branch_split, idx}]), else: MapSet.new()

      {emissions, base}
    end

    defp branch_split?(%{bracket_depth: 0, keywords: kw, seen_content: true}, %{content: c}),
      do: MapSet.member?(kw, c)

    defp branch_split?(_, _), do: false
  end
end
