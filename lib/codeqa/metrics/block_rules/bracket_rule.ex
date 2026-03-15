defmodule CodeQA.Metrics.BlockRules.BracketRule do
  @moduledoc """
  Detects sub-blocks delimited by matching bracket pairs: (), [], {}.
  Only top-level (depth-0) bracket expressions are returned as enclosures.
  Nested brackets are absorbed into the enclosing expression.
  """
  @behaviour CodeQA.Metrics.BlockRule

  @open MapSet.new(["(", "[", "{"])
  @close %{")" => "(", "]" => "[", "}" => "{"}

  @impl true
  def detect(tokens, _opts) do
    {_, _, _, enclosures} =
      tokens
      |> Enum.with_index()
      |> Enum.reduce({0, nil, [], []}, fn {token, idx}, {depth, start_idx, stack, enclosures} ->
        cond do
          MapSet.member?(@open, token) ->
            if depth == 0 do
              {1, idx, [token | stack], enclosures}
            else
              {depth + 1, start_idx, [token | stack], enclosures}
            end

          Map.has_key?(@close, token) ->
            expected_open = @close[token]
            case stack do
              [^expected_open | rest] ->
                new_depth = depth - 1
                if new_depth == 0 do
                  {0, nil, rest, [{:enclosure, start_idx, idx} | enclosures]}
                else
                  {new_depth, start_idx, rest, enclosures}
                end
              _ ->
                # mismatched bracket — ignore
                {depth, start_idx, stack, enclosures}
            end

          true ->
            {depth, start_idx, stack, enclosures}
        end
      end)

    Enum.reverse(enclosures)
  end
end
