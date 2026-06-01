defmodule CodeQA.AST.Signals.Structural.ColonIndentSignal do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @moduledoc """
  Emits `:colon_indent_enclosure` for colon-indented blocks (Python).

  Only active when `opts[:language_module]` returns true for `uses_colon_indent?/0`. Replaces
  `ParseRules.ColonIndentationRule`.

  ## Limitation

  The original rule flushes open blocks at EOF via `close_all_open/1`. Since
  `emit/3` has no end-of-stream callback, open blocks are instead flushed at
  each `<NL>` token. This correctly handles single-statement blocks; multi-line
  blocks are closed at the first newline (conservative).
  """

  defstruct []

  defimpl CodeQA.AST.Parsing.Signal do
    def source(_), do: CodeQA.AST.Signals.Structural.ColonIndentSignal
    def group(_), do: :enclosure

    def init(_, lang_mod) do
      %{
        enabled: lang_mod.uses_colon_indent?(),
        idx: 0,
        ci: 0,
        last_colon_indent: nil,
        stack: []
      }
    end

    def emit(_, _, %{enabled: false} = state),
      do: {MapSet.new(), %{state | idx: state.idx + 1}}

    def emit(_, {_, %NewlineToken{}, _}, %{idx: idx} = state) do
      {emissions, _} = flush_stack(state.stack)
      {emissions, %{state | idx: idx + 1, ci: 0, stack: []}}
    end

    def emit(_, {_, %WhitespaceToken{}, _}, %{idx: idx, ci: ci} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, ci: ci + 1}}

    def emit(_, {_, %{kind: ":"}, _}, %{idx: idx, ci: ci} = state),
      do: {MapSet.new(), %{state | idx: idx + 1, last_colon_indent: ci}}

    def emit(_, {_, _, _}, %{idx: idx, ci: ci} = state) do
      {dedent_emissions, remaining} = close_dedented(state.stack, ci)
      new_stack = maybe_open_block(remaining, state.last_colon_indent, ci, idx)

      {dedent_emissions,
       %{state | idx: idx + 1, last_colon_indent: nil, stack: update_top(new_stack, idx)}}
    end

    defp close_dedented(stack, ci) do
      {to_close, keep} = Enum.split_while(stack, fn e -> ci <= e.colon_indent end)
      {build_emissions(to_close), keep}
    end

    defp flush_stack(stack), do: {build_emissions(stack), []}

    defp maybe_open_block(stack, colon_indent, ci, idx)
         when colon_indent != nil and ci > colon_indent,
         do: [%{colon_indent: colon_indent, sub_start: idx, last_content_idx: idx} | stack]

    defp maybe_open_block(stack, _, _, _), do: stack

    defp build_emissions(entries) do
      Enum.reduce(entries, MapSet.new(), fn
        %{sub_start: s, last_content_idx: e}, acc when e != nil ->
          MapSet.put(acc, {:colon_indent_enclosure, {s, e}})

        _entry, acc ->
          acc
      end)
    end

    defp update_top([], _idx), do: []
    defp update_top([top | rest], idx), do: [Map.put(top, :last_content_idx, idx) | rest]
  end
end
