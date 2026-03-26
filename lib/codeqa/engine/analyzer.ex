defmodule CodeQA.Engine.Analyzer do
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
            |> Registry.register_file_metric(Metrics.LinePatterns)
            |> Registry.register_codebase_metric(CodebaseMetrics.Similarity)
            |> Registry.register_file_metric(Metrics.NearDuplicateBlocksFile)
            |> Registry.register_codebase_metric(CodebaseMetrics.NearDuplicateBlocksCodebase)

  def build_registry, do: @registry

  @spec analyze_file(String.t(), String.t()) :: map()
  def analyze_file(_path, content) do
    ctx = Pipeline.build_file_context(content)
    Registry.run_file_metrics(@registry, ctx, [])
  end

  @spec analyze_file_for_loo(String.t(), String.t()) :: map()
  def analyze_file_for_loo(_path, content) do
    ctx = Pipeline.build_file_context(content, skip_structural: true)
    Registry.run_file_metrics(@registry, ctx, [])
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
    opts = Keyword.put(opts, :file_context_pid, run_ctx.file_context_pid)
    opts = Keyword.put(opts, :behavior_config_pid, run_ctx.behavior_config_pid)

    try do
      fun.(opts)
    after
      Supervisor.stop(sup)
    end
  end

  defp do_analyze_codebase(files, opts) do
    registry = @registry
    file_results = Parallel.analyze_files(files, opts)
    aggregate = aggregate_file_metrics(file_results)

    if Keyword.get(opts, :compute_nodes, false) do
      nodes_opts =
        [baseline_codebase_agg: aggregate] ++
          Keyword.take(opts, [:nodes_top, :workers, :behavior_config_pid])

      pipeline_result = %{
        "files" => file_results,
        "codebase" => %{"aggregate" => aggregate}
      }

      updated_pipeline_result = BlockImpactAnalyzer.analyze(pipeline_result, files, nodes_opts)
      codebase_metrics = Registry.run_codebase_metrics(registry, files, opts)

      updated_codebase =
        Map.merge(codebase_metrics, updated_pipeline_result["codebase"])

      Map.put(updated_pipeline_result, "codebase", updated_codebase)
    else
      codebase_metrics = Registry.run_codebase_metrics(registry, files, opts)

      %{
        "files" => file_results,
        "codebase" => Map.put(codebase_metrics, "aggregate", aggregate)
      }
    end
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
    sum_squares = Enum.reduce(values, 0.0, fn v, acc -> acc + (v - mean) ** 2 end)
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
