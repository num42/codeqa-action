defmodule CodeQA.Parallel do
  @moduledoc "Parallel file analysis using Flow (GenStage-based)."

  def analyze_files(files, opts \\ []) when is_map(files) do
    if map_size(files) == 0, do: %{}, else: do_analyze(files, opts)
  end

  defp do_analyze(files, opts) do
    on_progress = Keyword.get(opts, :on_progress)
    cache_dir = Keyword.get(opts, :cache_dir)
    total = map_size(files)
    counter = :counters.new(1, [:atomics])

    if cache_dir do
      File.mkdir_p!(cache_dir)
    end

    stages = Keyword.get(opts, :workers, System.schedulers_online())

    files
    |> Flow.from_enumerable(max_demand: 5, stages: stages)
    |> Flow.map(fn {path, content} ->
      start_time = System.monotonic_time(:millisecond)

      result = maybe_cached_analyze(content, cache_dir, opts)

      end_time = System.monotonic_time(:millisecond)
      time_taken = end_time - start_time

      if on_progress do
        :counters.add(counter, 1, 1)
        completed = :counters.get(counter, 1)
        on_progress.(completed, total, path, time_taken)
      end

      {path, result}
    end)
    |> Enum.into(%{})
  end

  defp maybe_cached_analyze(content, nil, opts), do: analyze_single_file(content, opts)

  defp maybe_cached_analyze(content, cache_dir, opts) do
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    cache_file = Path.join(cache_dir, hash <> ".json")

    case File.read(cache_file) do
      {:ok, cached} ->
        case Jason.decode(cached) do
          {:ok, data} ->
            data

          _ ->
            data = analyze_single_file(content, opts)
            File.write!(cache_file, Jason.encode!(data))
            data
        end

      _ ->
        data = analyze_single_file(content, opts)
        File.write!(cache_file, Jason.encode!(data))
        data
    end
  end

  defp analyze_single_file(content, opts) do
    registry = CodeQA.Analyzer.build_registry()

    ctx =
      CodeQA.Telemetry.time(:pipeline_build_context, fn ->
        CodeQA.Pipeline.build_file_context(content, opts)
      end)

    metrics =
      CodeQA.Telemetry.time(:registry_run_metrics, fn ->
        CodeQA.Registry.run_file_metrics(registry, ctx, opts)
      end)

    %{
      "bytes" => ctx.byte_count,
      "lines" => ctx.line_count,
      "metrics" => metrics
    }
  end
end
