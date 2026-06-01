defmodule CodeQA.AST.Signals.Structural.BracketSignal do
  @moduledoc """
  Emits `:bracket_enclosure` for each outermost bracket pair `()`, `[]`, `{}`.

  Replaces `ParseRules.BracketRule`. State tracks: token index, bracket depth,
  start index of current open bracket, and a stack of open bracket kinds for
  mismatch detection.
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    @close %{")" => "(", "]" => "[", "}" => "{"}

    def source(_), do: CodeQA.AST.Signals.Structural.BracketSignal
    def group(_), do: :enclosure

    def init(_, _lang_mod), do: %{idx: 0, depth: 0, start_idx: nil, stack: []}

    def emit(_, {_, %{kind: k}, _}, %{idx: idx, depth: 0, stack: stack} = state)
        when k in ["(", "[", "{"],
        do: {MapSet.new(), %{state | idx: idx + 1, depth: 1, start_idx: idx, stack: [k | stack]}}

    def emit(_, {_, %{kind: k}, _}, %{idx: idx, depth: d, stack: stack} = state)
        when k in ["(", "[", "{"],
        do: {MapSet.new(), %{state | idx: idx + 1, depth: d + 1, stack: [k | stack]}}

    def emit(_, {_, %{kind: k}, _}, %{idx: idx, depth: d, stack: [top | rest]} = state)
        when k in [")", "]", "}"] do
      base = %{state | idx: idx + 1}

      if @close[k] == top,
        do: close_match(base, d, state.start_idx, idx, rest),
        else: {MapSet.new(), base}
    end

    def emit(_, {_, %{kind: k}, _}, %{idx: idx} = state) when k in [")", "]", "}"],
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, _, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    defp close_match(state, 1, start_idx, idx, rest),
      do:
        {MapSet.new([{:bracket_enclosure, {start_idx, idx}}]),
         %{state | depth: 0, start_idx: nil, stack: rest}}

    defp close_match(state, d, _start_idx, _idx, rest),
      do: {MapSet.new(), %{state | depth: d - 1, stack: rest}}
  end
end
