defmodule CodeQA.HealthReport.Delta do
  @moduledoc "Computes aggregate metric delta between two codebase analysis results."

  @spec compute(map(), map()) :: %{
          base: %{aggregate: map()},
          head: %{aggregate: map()},
          delta: %{aggregate: map()}
        }
  def compute(base_results, head_results) do
    base_agg = get_in(base_results, ["codebase", "aggregate"]) || %{}
    head_agg = get_in(head_results, ["codebase", "aggregate"]) || %{}

    %{
      base: %{aggregate: base_agg},
      head: %{aggregate: head_agg},
      delta: %{aggregate: compute_aggregate_delta(base_agg, head_agg)}
    }
  end

  defp compute_aggregate_delta(base_agg, head_agg) do
    MapSet.new(Map.keys(base_agg) ++ Map.keys(head_agg))
    |> Enum.reduce(%{}, fn metric_name, acc ->
      base_m = Map.get(base_agg, metric_name, %{})
      head_m = Map.get(head_agg, metric_name, %{})
      delta = compute_numeric_delta(base_m, head_m)
      if delta == %{}, do: acc, else: Map.put(acc, metric_name, delta)
    end)
  end

  defp compute_numeric_delta(base, head) do
    MapSet.new(Map.keys(base) ++ Map.keys(head))
    |> Enum.reduce(%{}, fn key, acc ->
      case {Map.get(base, key), Map.get(head, key)} do
        {b, h} when is_number(b) and is_number(h) ->
          Map.put(acc, key, Float.round(h - b, 4))

        _ ->
          acc
      end
    end)
  end
end
