defmodule CodeQA.LineReport do
  @moduledoc "Per-line metric impact analysis."

  alias CodeQA.{Analyzer, Collector, Pipeline, Registry}

  # Metrics excluded entirely from line report (whole-file aggregates, insensitive to single-line removal)
  @excluded_metrics MapSet.new(["compression"])

  # Sub-metric keys excluded per metric (noisy or meaningless at line granularity)
  @excluded_keys %{
    "entropy" => MapSet.new(["char_entropy", "char_normalized", "token_normalized"]),
    "halstead" => MapSet.new(["n1_unique_operators"]),
    "indentation" => MapSet.new(["max_depth"]),
    "readability" => MapSet.new(["total_lines"])
  }

  @spec analyze_path(String.t(), keyword()) :: %{String.t() => %{baseline: map(), lines: [map()]}}
  def analyze_path(path, opts \\ []) do
    ignore_patterns = Keyword.get(opts, :ignore_patterns, [])

    files =
      if File.dir?(path) do
        Collector.collect_files(path, ignore_patterns: ignore_patterns)
      else
        %{path => File.read!(path)}
      end

    files
    |> Flow.from_enumerable(
      max_demand: 1,
      stages: Keyword.get(opts, :workers, System.schedulers_online())
    )
    |> Flow.map(fn {file_path, content} ->
      {file_path, analyze_file(content, opts)}
    end)
    |> Enum.into(%{})
  end

  @spec analyze_file(String.t(), keyword()) :: %{baseline: map(), lines: [map()]}
  def analyze_file(content, opts \\ []) do
    metric_filter = Keyword.get(opts, :metrics)
    pipeline_opts = Keyword.take(opts, [:word_stopwords])

    registry = build_filtered_registry(metric_filter)
    ctx = Pipeline.build_file_context(content, pipeline_opts)
    baseline = Registry.run_file_metrics(registry, ctx)

    all_lines = String.split(content, "\n")

    source_lines =
      all_lines
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _idx} -> line == "" end)

    lines =
      source_lines
      |> Task.async_stream(
        fn {line_content, line_number} ->
          without = remove_line(all_lines, line_number)
          ctx_without = Pipeline.build_file_context(without, pipeline_opts)
          metrics_without = Registry.run_file_metrics(registry, ctx_without)
          impact = compute_impact(baseline, metrics_without) |> filter_excluded_keys()

          %{line_number: line_number, content: line_content, impact: impact}
        end,
        max_concurrency: System.schedulers_online(),
        ordered: true
      )
      |> Enum.map(fn {:ok, result} -> result end)

    %{baseline: filter_excluded_keys(baseline), lines: lines}
  end

  @spec format_table(%{baseline: map(), lines: [map()]}) :: String.t()
  def format_table(%{lines: lines}) do
    metric_keys = collect_metric_keys(lines)

    lines
    |> Enum.map(fn %{line_number: n, content: c, impact: impact} ->
      metrics_str =
        metric_keys
        |> Enum.map(fn {metric, key} ->
          case get_in(impact, [metric, key]) do
            nil -> nil
            value -> "#{short_metric_name(metric, key)}: #{format_delta(value)}"
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.join("  ")

      "#{String.pad_leading(Integer.to_string(n), 4)} | #{c}  | #{metrics_str}"
    end)
    |> Enum.join("\n")
  end

  defp build_filtered_registry(nil) do
    full = Analyzer.build_registry()
    filtered = Enum.reject(full.file_metrics, &MapSet.member?(@excluded_metrics, &1.name()))
    %{full | file_metrics: filtered, codebase_metrics: []}
  end

  defp build_filtered_registry(metric_names) when is_list(metric_names) do
    names_set = MapSet.new(metric_names)
    full_registry = Analyzer.build_registry()

    filtered =
      Enum.filter(full_registry.file_metrics, &MapSet.member?(names_set, &1.name()))

    %{full_registry | file_metrics: filtered, codebase_metrics: []}
  end

  defp remove_line(all_lines, line_number) do
    all_lines
    |> List.delete_at(line_number - 1)
    |> Enum.join("\n")
  end

  defp filter_excluded_keys(metrics) do
    Map.new(metrics, fn {metric_name, data} ->
      case Map.get(@excluded_keys, metric_name) do
        nil -> {metric_name, data}
        excluded -> {metric_name, Map.drop(data, MapSet.to_list(excluded))}
      end
    end)
  end

  defp compute_impact(baseline, without) do
    Map.new(baseline, fn {metric_name, baseline_data} ->
      without_data = Map.get(without, metric_name, %{})

      impact_data =
        baseline_data
        |> Enum.filter(fn {key, bv} ->
          is_number(bv) and is_number(Map.get(without_data, key))
        end)
        |> Map.new(fn {key, bv} ->
          {key, bv - Map.fetch!(without_data, key)}
        end)

      {metric_name, impact_data}
    end)
  end

  defp collect_metric_keys([]), do: []

  defp collect_metric_keys([first | _]) do
    first.impact
    |> Enum.flat_map(fn {metric, data} ->
      Enum.map(data, fn {key, _v} -> {metric, key} end)
    end)
    |> Enum.take(8)
  end

  defp short_metric_name(metric, key) do
    "#{String.slice(metric, 0, 4)}.#{String.slice(key, 0, 6)}"
  end

  defp format_delta(value) when is_float(value) do
    sign = if value >= 0, do: "+", else: ""
    "#{sign}#{Float.round(value, 2)}"
  end

  defp format_delta(value) when is_integer(value) do
    sign = if value >= 0, do: "+", else: ""
    "#{sign}#{value}"
  end
end
