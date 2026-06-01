defmodule CodeQA.Engine.Analyzer do
  alias CodeQA.CombinedMetrics.Scorer
  @moduledoc "Orchestrates metric computation across files."

  alias CodeQA.Analysis.RunSupervisor
  alias CodeQA.BlockImpactAnalyzer
  alias CodeQA.Engine.Parallel
  alias CodeQA.Engine.Pipeline
  alias CodeQA.Engine.Registry
  alias CodeQA.Metrics.Codebase, as: CodebaseMetrics
  alias CodeQA.Metrics.File, as: Metrics

  @registry Registry.new()
            |> Registry.register_file_metric(Metrics.Entropy)
            |> Registry.register_file_metric(Metrics.Compression)
            |> Registry.register_file_metric(Metrics.Zipf)
            |> Registry.register_file_metric(Metrics.Heaps)
            |> Registry.register_file_metric(Metrics.Vocabulary)
            |> Registry.register_file_metric(Metrics.Ngram)
            |> Registry.register_file_metric(Metrics.Halstead)
            |> Registry.register_file_metric(Metrics.Readability)
            |> Registry.register_file_metric(Metrics.CasingEntropy)
            |> Registry.register_file_metric(Metrics.IdentifierLengthVariance)
            |> Registry.register_file_metric(Metrics.Indentation)
            |> Registry.register_file_metric(Metrics.Branching)
            |> Registry.register_file_metric(Metrics.FunctionMetrics)
            |> Registry.register_file_metric(Metrics.MagicNumberDensity)
            |> Registry.register_file_metric(Metrics.SymbolDensity)
            |> Registry.register_file_metric(Metrics.VowelDensity)
            |> Registry.register_file_metric(Metrics.Brevity)
            |> Registry.register_file_metric(Metrics.PunctuationDensity)
            |> Registry.register_file_metric(Metrics.CommentStructure)
            |> Registry.register_file_metric(Metrics.SeparatorCounts)
            |> Registry.register_file_metric(Metrics.LinePatterns)
            |> Registry.register_codebase_metric(CodebaseMetrics.Similarity)
            |> Registry.register_file_metric(Metrics.NearDuplicateBlocksFile)
            |> Registry.register_codebase_metric(CodebaseMetrics.NearDuplicateBlocksCodebase)

  def build_registry, do: @registry

  @spec analyze_file(String.t(), String.t()) :: map()
  def analyze_file(_path, content) do
    context = Pipeline.build_file_context(content)
    Registry.run_file_metrics(@registry, context, [])
  end

  @spec analyze_file_for_loo(String.t(), String.t()) :: map()
  def analyze_file_for_loo(_path, content) do
    context = Pipeline.build_file_context(content, skip_structural: true)
    Registry.run_file_metrics(@registry, context, [])
  end

  @doc """
  Like `analyze_file_for_loo/2` but only re-runs file metrics whose name is in
  `Scorer.referenced_file_metric_names/0`. Metrics not referenced by any
  behavior YAML inherit their value from `baseline_metrics`. Metrics that
  implement the optional `analyze_loo/2` callback derive their LOO value from
  the baseline + the removed block's content, skipping a full file re-analyze.
  """
  @spec analyze_file_for_loo_partial(String.t(), String.t(), map(), String.t()) :: map()
  def analyze_file_for_loo_partial(_path, content, baseline_metrics, block_content \\ "") do
    referenced = Scorer.referenced_file_metric_names()

    {ctx_us, ctx} =
      :timer.tc(fn -> Pipeline.build_file_context(content, skip_structural: true) end)

    {result, breakdown} =
      baseline_metrics
      |> Enum.reduce({[], %{ctx: ctx_us}}, fn {name, baseline_value}, {acc, breakdown} ->
        if MapSet.member?(referenced, name) do
          mod = registered_module_for(name)

          {us, value} =
            if function_exported?(mod, :analyze_loo, 2) do
              :timer.tc(fn -> mod.analyze_loo(baseline_value, block_content) end)
            else
              :timer.tc(fn -> mod.analyze(ctx) end)
            end

          {[{name, value} | acc], Map.put(breakdown, name, us)}
        else
          {[{name, baseline_value} | acc], breakdown}
        end
      end)

    :telemetry.execute([:codeqa, :loo_breakdown], breakdown, %{})
    Map.new(result)
  end

  defp registered_module_for(name) do
    Enum.find(@registry.file_metrics, &(&1.name() == name)) ||
      raise "no registered file metric module for name #{inspect(name)}"
  end

  @spec analyze_codebase_aggregate(map(), keyword()) :: map()
  def analyze_codebase_aggregate(files_map, opts \\ []) do
    with_run_context(opts, fn opts ->
      file_results = Parallel.analyze_files(files_map, opts)
      aggregate_file_metrics(file_results)
    end)
  end

  def analyze_codebase(files, opts \\ []) do
    with_run_context(opts, &do_analyze_codebase(files, &1))
  end

  defp with_run_context(opts, fun) do
    {:ok, sup} = RunSupervisor.start_link()
    run_ctx = RunSupervisor.run_context(sup)
    opts = opts |> Keyword.put(:file_context_pid, run_ctx.file_context_pid)
    opts = opts |> Keyword.put(:behavior_config_pid, run_ctx.behavior_config_pid)

    try do
      fun.(opts)
    after
      Supervisor.stop(sup)
    end
  end

  defp do_analyze_codebase(files, opts) do
    registry = @registry

    file_results =
      stage(:parallel_files, %{file_count: map_size(files)}, fn ->
        Parallel.analyze_files(files, opts)
      end)

    aggregate = stage(:aggregate, %{}, fn -> aggregate_file_metrics(file_results) end)

    if Keyword.get(opts, :compute_nodes, false) do
      nodes_opts =
        [baseline_codebase_agg: aggregate] ++
          Keyword.take(opts, [:nodes_top, :workers, :behavior_config_pid])

      pipeline_result = %{
        "files" => file_results,
        "codebase" => %{"aggregate" => aggregate}
      }

      updated_pipeline_result =
        stage(:block_impact, %{file_count: map_size(files)}, fn ->
          BlockImpactAnalyzer.analyze(pipeline_result, files, nodes_opts)
        end)

      codebase_metrics =
        stage(:codebase_metrics, %{file_count: map_size(files)}, fn ->
          Registry.run_codebase_metrics(registry, files, opts)
        end)

      updated_codebase =
        Map.merge(codebase_metrics, updated_pipeline_result["codebase"])

      Map.put(updated_pipeline_result, "codebase", updated_codebase)
    else
      codebase_metrics =
        stage(:codebase_metrics, %{file_count: map_size(files)}, fn ->
          Registry.run_codebase_metrics(registry, files, opts)
        end)

      %{
        "files" => file_results,
        "codebase" => Map.put(codebase_metrics, "aggregate", aggregate)
      }
    end
  end

  defp stage(name, metadata, fun) do
    t0 = System.monotonic_time(:microsecond)
    result = fun.()
    duration = System.monotonic_time(:microsecond) - t0
    :telemetry.execute([:codeqa, :stage], %{duration: duration}, Map.put(metadata, :stage, name))
    result
  end

  defp metric_data_to_triples({metric_name, metric_data}) do
    metric_data
    |> Enum.filter(fn {_k, v} -> is_number(v) end)
    |> Enum.map(fn {key, value} -> {metric_name, key, value / 1} end)
  end

  def aggregate_file_metrics(file_results) do
    file_results
    |> Map.values()
    |> Enum.flat_map(fn file_data ->
      file_data
      |> Map.get("metrics", %{})
      |> Enum.flat_map(&metric_data_to_triples/1)
    end)
    |> Enum.group_by(fn {metric, key, _val} -> {metric, key} end, fn {_, _, val} -> val end)
    |> Enum.reduce(%{}, fn {{metric, key}, values}, acc ->
      stats = compute_stats(values)
      metric_agg = Map.get(acc, metric, %{})

      updated =
        Map.merge(metric_agg, %{
          "mean_#{key}" => stats.mean,
          "std_#{key}" => stats.std,
          "min_#{key}" => stats.min,
          "max_#{key}" => stats.max
        })

      Map.put(acc, metric, updated)
    end)
  end

  defp compute_stats([]), do: %{mean: 0.0, std: 0.0, min: 0.0, max: 0.0}

  defp compute_stats(values) do
    n = length(values)
    mean = Enum.sum(values) / n
    sum_squares = values |> Enum.reduce(0.0, fn v, acc -> acc + (v - mean) ** 2 end)
    variance = sum_squares / n
    std = :math.sqrt(variance)

    %{
      mean: Float.round(mean * 1.0, 4),
      std: Float.round(std * 1.0, 4),
      min: Float.round(Enum.min(values) * 1.0, 4),
      max: Float.round(Enum.max(values) * 1.0, 4)
    }
  end
end
