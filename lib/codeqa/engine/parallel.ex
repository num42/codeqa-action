defmodule CodeQA.Engine.Parallel do
  alias CodeQA.Analysis.FileContextServer
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Registry

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

      result = maybe_cached_analyze(path, content, cache_dir, opts)

      end_time = System.monotonic_time(:millisecond)
      time_taken = end_time - start_time

      if on_progress do
        :counters.add(counter, 1, 1)
        completed = :counters.get(counter, 1)
        on_progress.(completed, total, path, time_taken)
      end

      {path, result}
    end)
    |> Map.new()
  end

  defp maybe_cached_analyze(path, content, nil, opts),
    do: analyze_single_file(path, content, opts)

  defp maybe_cached_analyze(path, content, cache_dir, opts) do
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    cache_file = Path.join(cache_dir, hash <> ".json")

    File.read(cache_file) |> handle_maybe_cached_analyze_read(cache_file, content, opts, path)
  end

  defp analyze_single_file(path, content, opts) do
    registry = Analyzer.build_registry()
    file_opts = Keyword.put(opts, :path, path)
    pid = Keyword.fetch!(opts, :file_context_pid)

    ctx = FileContextServer.get(pid, content, file_opts)
    metrics = Registry.run_file_metrics(registry, ctx, opts)

    %{
      "bytes" => ctx.byte_count,
      "lines" => ctx.line_count,
      "metrics" => metrics
    }
  end

  # FIXME: extracted automatically by ExtractCaseToHelper — review
  # the parameter list and consider a better name.
  defp handle_maybe_cached_analyze_read({:ok, cached}, cache_file, content, opts, path) do
    Jason.decode(cached)
    |> handle_maybe_cached_analyze_read_decode(cache_file, content, opts, path)
  end

  defp handle_maybe_cached_analyze_read(_, cache_file, content, opts, path) do
    data = analyze_single_file(path, content, opts)
    File.write!(cache_file, Jason.encode!(data))
    data
  end

  # FIXME: extracted automatically by ExtractCaseToHelper — review
  # the parameter list and consider a better name.
  defp handle_maybe_cached_analyze_read_decode({:ok, data}, _cache_file, _content, _opts, _path) do
    data
  end

  defp handle_maybe_cached_analyze_read_decode(_, cache_file, content, opts, path) do
    data = analyze_single_file(path, content, opts)
    File.write!(cache_file, Jason.encode!(data))
    data
  end
end
