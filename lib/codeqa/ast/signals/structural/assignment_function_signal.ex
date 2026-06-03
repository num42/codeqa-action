defmodule CodeQA.AST.Signals.Structural.AssignmentFunctionSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:assignment_function_split` when a top-level assignment to a function
  is detected at indent 0 and bracket depth 0.

  Covers patterns such as:
  - `identifier = function(...) {}`
  - `identifier = async function(...) {}`
  - `identifier = (...) => {}`
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.AssignmentFunctionSignal
    def group(_), do: :split

    def init(_, _lang_mod),
      do: %{
        at_line_start: true,
        bracket_depth: 0,
        idx: 0,
        indent: 0,
        phase: :idle,
        seen_content: false
      }

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, indent: 0, at_line_start: true, phase: :idle}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{at_line_start: true, idx: idx, indent: i} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, indent: i + 1, at_line_start: true}}

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx} = state),
      do: {MapSet.new(), %{state | idx: idx + 1}}

    def emit(_, {_, %{kind: k}, _}, %{bracket_depth: bd, idx: idx, phase: phase} = state)
        when k in ["(", "[", "{"] do
      new_bd = bd + 1
      new_phase = advance_phase_open(phase, k)

      {MapSet.new(),
       %{
         state
         | idx: idx + 1,
           bracket_depth: new_bd,
           at_line_start: false,
           seen_content: true,
           phase: new_phase
       }}
    end

    def emit(_, {_, %{kind: k}, _}, %{bracket_depth: bd, idx: idx, phase: phase} = state)
        when k in [")", "]", "}"] do
      new_bd = max(0, bd - 1)
      new_phase = advance_phase_close(phase, k)

      {MapSet.new(),
       %{
         state
         | idx: idx + 1,
           bracket_depth: new_bd,
           at_line_start: false,
           seen_content: true,
           phase: new_phase
       }}
    end

    def emit(
          _,
          {_, token, _},
          %{
            at_line_start: als,
            bracket_depth: bd,
            idx: idx,
            indent: i,
            phase: phase,
            seen_content: sc
          } = state
        ) do
      {emissions, new_phase} = advance_phase(phase, token, idx, sc, i, bd, als)

      {emissions,
       %{state | idx: idx + 1, at_line_start: false, seen_content: true, phase: new_phase}}
    end

    defp advance_phase_open({:in_parens, id_idx, pd}, "("), do: {:in_parens, id_idx, pd + 1}
    defp advance_phase_open({:in_parens, id_idx, pd}, _), do: {:in_parens, id_idx, pd}
    defp advance_phase_open({:saw_eq, id_idx}, "("), do: {:in_parens, id_idx, 1}
    defp advance_phase_open(_, _), do: :idle

    defp advance_phase_close({:in_parens, id_idx, 1}, ")"), do: {:saw_close_paren, id_idx}

    defp advance_phase_close({:in_parens, id_idx, pd}, ")") when pd > 1,
      do: {:in_parens, id_idx, pd - 1}

    defp advance_phase_close({:in_parens, id_idx, pd}, _), do: {:in_parens, id_idx, pd}
    defp advance_phase_close(_, _), do: :idle

    defp advance_phase(:idle, %{kind: "<ID>"}, idx, true, 0, 0, true),
      do: {MapSet.new(), {:saw_id, idx}}

    defp advance_phase(:idle, _, _, _, _, _, _), do: {MapSet.new(), :idle}

    defp advance_phase({:saw_id, id_idx}, %{kind: "="}, _, _, _, _, _),
      do: {MapSet.new(), {:saw_eq, id_idx}}

    defp advance_phase({:saw_id, _}, %{kind: "<ID>"}, idx, _, _, _, _),
      do: {MapSet.new(), {:saw_id, idx}}

    defp advance_phase({:saw_id, id_idx}, %{kind: "."}, _, _, _, _, _),
      do: {MapSet.new(), {:saw_id, id_idx}}

    defp advance_phase({:saw_id, _}, _, _, _, _, _, _), do: {MapSet.new(), :idle}

    defp advance_phase({:saw_eq, id_idx}, %{content: "function", kind: "<ID>"}, _, _, _, _, _),
      do: {MapSet.new([{:assignment_function_split, id_idx}]), :idle}

    defp advance_phase({:saw_eq, id_idx}, %{content: "async", kind: "<ID>"}, _, _, _, _, _),
      do: {MapSet.new(), {:saw_eq, id_idx}}

    defp advance_phase({:saw_eq, _}, _, _, _, _, _, _), do: {MapSet.new(), :idle}

    defp advance_phase({:saw_close_paren, id_idx}, %{kind: "=>"}, _, _, _, _, _),
      do: {MapSet.new([{:assignment_function_split, id_idx}]), :idle}

    defp advance_phase({:saw_close_paren, _}, _, _, _, _, _, _), do: {MapSet.new(), :idle}

    defp advance_phase(_, _, _, _, _, _, _), do: {MapSet.new(), :idle}
  end
end
