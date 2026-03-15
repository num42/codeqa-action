defmodule CodeQA.Metrics.BlockRules.ColonIndentationRule do
  @moduledoc """
  Detects Python-style colon+indentation sub-blocks.
  A sub-block starts when ':' appears at end of a line and the next
  non-empty line has greater indentation. Ends when indentation drops back.
  """
  @behaviour CodeQA.Metrics.BlockRule

  @impl true
  def detect(tokens, _opts) do
    tokens
    |> Enum.with_index()
    |> scan(%{current_indent: 0, last_colon_indent: nil, stack: [], enclosures: []})
    |> close_all_open()
    |> Map.get(:enclosures)
    |> Enum.reverse()
  end

  defp scan([], state), do: state

  defp scan([{token, idx} | rest], state) do
    state = update_state(token, idx, state)
    scan(rest, state)
  end

  defp update_state("<NL>", _idx, state) do
    %{state | current_indent: 0}
  end

  defp update_state("<WS>", _idx, %{current_indent: ci} = state) do
    %{state | current_indent: ci + 1}
  end

  defp update_state(":", _idx, state) do
    %{state | last_colon_indent: state.current_indent}
  end

  defp update_state(token, idx, state) when token not in ["<NL>", "<WS>", ":"] do
    ci = state.current_indent

    # Close any open stack entries where current indent has dropped back
    state = close_stack_entries(state, ci, idx)

    # If there's a pending colon at a lower indent level, open a new sub-block
    state =
      if state.last_colon_indent != nil and ci > state.last_colon_indent do
        entry = %{colon_indent: state.last_colon_indent, sub_start: idx}
        %{state | stack: [entry | state.stack], last_colon_indent: nil}
      else
        %{state | last_colon_indent: nil}
      end

    # Track last content index on the top stack entry
    state = update_top_last_idx(state, idx)

    state
  end

  defp close_stack_entries(%{stack: stack, enclosures: encs} = state, ci, _idx) do
    {closed, remaining} =
      Enum.split_while(stack, fn entry -> ci <= entry.colon_indent end)

    new_encs =
      Enum.reduce(closed, encs, fn entry, acc ->
        case entry do
          %{sub_start: s, last_content_idx: e} when e != nil ->
            [{:enclosure, s, e} | acc]
          _ ->
            acc
        end
      end)

    %{state | stack: remaining, enclosures: new_encs}
  end

  defp update_top_last_idx(%{stack: [top | rest]} = state, idx) do
    %{state | stack: [Map.put(top, :last_content_idx, idx) | rest]}
  end

  defp update_top_last_idx(state, _idx), do: state

  defp close_all_open(%{stack: stack, enclosures: encs} = state) do
    new_encs =
      Enum.reduce(stack, encs, fn entry, acc ->
        case entry do
          %{sub_start: s, last_content_idx: e} when e != nil ->
            [{:enclosure, s, e} | acc]
          _ ->
            acc
        end
      end)

    %{state | stack: [], enclosures: new_encs}
  end
end
