defmodule CodeQA.Comparator do
  @moduledoc "Compare two analysis results and compute metric deltas."

  def compare_results(base_result, head_result, changes) do
    base_files = Map.get(base_result, "files", %{})
    head_files = Map.get(head_result, "files", %{})

    {file_comparisons, status_counts} =
      changes
      |> Enum.reduce({%{}, %{"added" => 0, "modified" => 0, "deleted" => 0}}, fn change, {files, counts} ->
        base_data = Map.get(base_files, change.path)
        head_data = Map.get(head_files, change.path)
        delta = compute_file_delta(base_data, head_data)

        file_entry = %{
          "status" => change.status,
          "base" => base_data,
          "head" => head_data,
          "delta" => delta
        }

        {Map.put(files, change.path, file_entry),
         Map.update!(counts, change.status, &(&1 + 1))}
      end)

    base_agg = get_in(base_result, ["codebase", "aggregate"]) || %{}
    head_agg = get_in(head_result, ["codebase", "aggregate"]) || %{}
    agg_delta = compute_aggregate_delta(base_agg, head_agg)

    summary = build_summary(status_counts)

    %{
      "metadata" => %{
        "total_files_compared" => length(changes),
        "summary" => summary
      },
      "files" => file_comparisons,
      "codebase" => %{
        "base" => %{"aggregate" => base_agg},
        "head" => %{"aggregate" => head_agg},
        "delta" => %{"aggregate" => agg_delta}
      }
    }
  end

  defp compute_file_delta(nil, _head), do: nil
  defp compute_file_delta(_base, nil), do: nil

  defp compute_file_delta(base_data, head_data) do
    top_delta =
      ["bytes", "lines"]
      |> Enum.reduce(%{}, fn key, acc ->
        case {Map.get(base_data, key), Map.get(head_data, key)} do
          {b, h} when is_number(b) and is_number(h) -> Map.put(acc, key, h - b)
          _ -> acc
        end
      end)

    base_metrics = Map.get(base_data, "metrics", %{})
    head_metrics = Map.get(head_data, "metrics", %{})

    metrics_delta =
      MapSet.new(Map.keys(base_metrics) ++ Map.keys(head_metrics))
      |> Enum.reduce(%{}, fn metric_name, acc ->
        base_m = Map.get(base_metrics, metric_name, %{})
        head_m = Map.get(head_metrics, metric_name, %{})
        delta = compute_numeric_delta(base_m, head_m)
        if delta == %{}, do: acc, else: Map.put(acc, metric_name, delta)
      end)

    Map.put(top_delta, "metrics", metrics_delta)
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
          Map.put(acc, key, Float.round((h - b) / 1, 4))
        _ -> acc
      end
    end)
  end

  defp build_summary(counts) do
    parts =
      [{"added", counts["added"]}, {"modified", counts["modified"]}, {"deleted", counts["deleted"]}]
      |> Enum.filter(fn {_, c} -> c > 0 end)
      |> Enum.map(fn {status, count} -> "#{count} #{status}" end)

    if parts == [], do: "no changes", else: Enum.join(parts, ", ")
  end
end
