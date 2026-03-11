defmodule CodeQA.Summarizer do
  @moduledoc false

  @codebase_direction_metrics [
    {"complexity", "halstead", "mean_volume"},
    {"readability", "readability", "mean_flesch_adapted"},
    {"entropy", "entropy", "mean_char_entropy"},
    {"redundancy", "compression", "mean_redundancy"}
  ]

  @file_direction_metrics [
    {"complexity", "halstead", "volume"},
    {"readability", "readability", "flesch_adapted"},
    {"entropy", "entropy", "char_entropy"},
    {"redundancy", "compression", "redundancy"}
  ]

  @threshold_stable 0.05
  @threshold_slight 0.20

  def summarize_codebase(comparison) do
    files = Map.get(comparison, "files", %{})
    codebase = Map.get(comparison, "codebase", %{})

    file_counts = count_statuses(files)
    directions = compute_codebase_directions(codebase)
    gist = build_codebase_gist(file_counts, directions)

    %{"gist" => gist, "file_counts" => file_counts, "directions" => directions}
  end

  def summarize_file(_path, %{"status" => "added"} = data) do
    lines = get_in(data, ["head", "lines"]) || 0
    %{"gist" => "new file (#{lines} lines)", "status" => "added", "lines" => lines}
  end

  def summarize_file(_path, %{"status" => "deleted"} = data) do
    lines = get_in(data, ["base", "lines"]) || 0
    %{"gist" => "removed (#{lines} lines)", "status" => "deleted", "lines" => lines}
  end

  def summarize_file(_path, %{"status" => "modified"} = data) do
    directions = compute_file_directions(data)
    gist = build_file_gist(directions)
    %{"gist" => gist, "status" => "modified", "directions" => directions}
  end

  defp count_statuses(files) do
    Enum.reduce(files, %{"added" => 0, "modified" => 0, "deleted" => 0}, fn {_path, data}, acc ->
      status = Map.get(data, "status", "modified")
      Map.update!(acc, status, &(&1 + 1))
    end)
  end

  defp compute_codebase_directions(codebase) do
    base_agg = get_in(codebase, ["base", "aggregate"]) || %{}
    delta_agg = get_in(codebase, ["delta", "aggregate"]) || %{}

    Map.new(@codebase_direction_metrics, fn {dir_key, metric, agg_key} ->
      base_val = get_in(base_agg, [metric, agg_key])
      delta_val = get_in(delta_agg, [metric, agg_key])
      {dir_key, classify_change(base_val, delta_val)}
    end)
  end

  defp compute_file_directions(file_data) do
    base_metrics = get_in(file_data, ["base", "metrics"]) || %{}
    delta_metrics = get_in(file_data, ["delta", "metrics"]) || %{}

    Map.new(@file_direction_metrics, fn {dir_key, metric, key} ->
      base_val = get_in(base_metrics, [metric, key])
      delta_val = get_in(delta_metrics, [metric, key])
      {dir_key, classify_change(base_val, delta_val)}
    end)
  end

  defp classify_change(nil, _), do: "stable"
  defp classify_change(_, nil), do: "stable"
  defp classify_change(0, _), do: "stable"
  defp classify_change(+0.0, _), do: "stable"

  defp classify_change(base_val, delta_val) do
    ratio = abs(delta_val) / abs(base_val)

    cond do
      ratio < @threshold_stable -> "stable"
      ratio < @threshold_slight and delta_val > 0 -> "increased slightly"
      ratio < @threshold_slight -> "decreased slightly"
      delta_val > 0 -> "increased"
      true -> "decreased"
    end
  end

  defp build_file_gist(directions) do
    parts = directions |> Enum.reject(fn {_, d} -> d == "stable" end) |> Enum.map(fn {k, d} -> "#{k} #{d}" end)
    if parts == [], do: "all metrics stable", else: Enum.join(parts, ", ")
  end

  defp build_codebase_gist(file_counts, directions) do
    file_parts =
      [{"added", file_counts["added"]}, {"modified", file_counts["modified"]}, {"deleted", file_counts["deleted"]}]
      |> Enum.filter(fn {_, c} -> c > 0 end)
      |> Enum.map(fn {s, c} -> "#{c} #{s}" end)

    file_summary = if file_parts == [], do: "no changes", else: Enum.join(file_parts, ", ")

    dir_parts = directions |> Enum.reject(fn {_, d} -> d == "stable" end) |> Enum.map(fn {k, d} -> "#{k} #{d}" end)

    if dir_parts == [] do
      "#{file_summary} — all metrics stable"
    else
      "#{file_summary} — #{Enum.join(dir_parts, ", ")}"
    end
  end
end
