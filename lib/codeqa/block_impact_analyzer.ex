defmodule CodeQA.BlockImpactAnalyzer do
  @moduledoc """
  Orchestrates block impact analysis across all files in a pipeline result.

  For each file, tokenizes its content, parses it into a node tree, and for each
  node (recursively including children) computes refactoring potentials via
  leave-one-out impact scoring at both file scope and codebase scope.

  The pipeline result is returned with a `"nodes"` key added to each file entry.
  All other keys in the result are preserved unchanged.

  ## Telemetry

  Emits the following events (all durations in microseconds):

    - `[:codeqa, :block_impact, :analyze]` — full run
      measurements: `%{duration: us}`
      metadata: `%{file_count: n}`

    - `[:codeqa, :block_impact, :codebase_cosines]` — codebase baseline cosine computation
      measurements: `%{duration: us}`
      metadata: `%{behavior_count: n}`

    - `[:codeqa, :block_impact, :file]` — per-file node computation
      measurements: `%{duration: us, tokenize_us: us, parse_us: us, file_cosines_us: us, node_count: n}`
      metadata: `%{path: string}`

    - `[:codeqa, :block_impact, :node]` — per-node leave-one-out computation
      measurements: `%{duration: us, reconstruct_us: us, analyze_file_us: us, aggregate_us: us, refactoring_us: us}`
      metadata: `%{path: string, token_count: n}`
  """

  alias CodeQA.Analysis.BehaviorConfigServer
  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.BlockImpact.{FileImpact, RefactoringPotentials}
  alias CodeQA.CombinedMetrics.{FileScorer, SampleRunner}
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Languages.Unknown

  @min_tokens 10

  @doc """
  Analyzes all files in the pipeline result, adding `"nodes"` to each file entry.

  ## Parameters

  - `pipeline_result` — direct return value of `Engine.Analyzer.analyze_codebase/2`,
    containing `"files"` and `"codebase"` keys
  - `files_map` — raw `%{path => content}` map used for file-scope leave-one-out
  - `opts` — keyword options

  ## Options

  - `:nodes_top` — number of refactoring potentials per node (default 3)
  - `:workers` — parallelism for `Task.async_stream` (default `System.schedulers_online()`)
  - `:baseline_codebase_agg` — pre-computed codebase aggregate (skips redundant analysis)
  """
  @spec analyze(map(), map(), keyword()) :: map()
  def analyze(pipeline_result, files_map, opts \\ []) do
    nodes_top = Keyword.get(opts, :nodes_top, 3)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    t0 = now()

    baseline_codebase_agg =
      Keyword.get_lazy(opts, :baseline_codebase_agg, fn ->
        Analyzer.analyze_codebase_aggregate(files_map)
      end)

    cached_behaviors =
      case Keyword.get(opts, :behavior_config_pid) do
        nil -> nil
        pid -> BehaviorConfigServer.get_all_behaviors(pid)
      end

    project_langs = project_languages(files_map)

    filtered_behaviors =
      if cached_behaviors && project_langs != [] do
        filter_behaviors_by_languages(cached_behaviors, project_langs)
      else
        cached_behaviors
      end

    {baseline_codebase_cosines, cosines_us} =
      timed(fn ->
        SampleRunner.diagnose_aggregate(baseline_codebase_agg,
          top: 99_999,
          languages: project_langs,
          behavior_map: filtered_behaviors
        )
      end)

    :telemetry.execute(
      [:codeqa, :block_impact, :codebase_cosines],
      %{duration: cosines_us},
      %{behavior_count: length(baseline_codebase_cosines)}
    )

    file_results = pipeline_result["files"]

    updated_files =
      file_results
      |> Task.async_stream(
        fn {path, file_data} ->
          content = Map.get(files_map, path, "")
          baseline_file_metrics = Map.get(file_data, "metrics", %{})

          {nodes, file_measurements} =
            compute_nodes_timed(
              path,
              content,
              baseline_file_metrics,
              file_results,
              baseline_codebase_cosines,
              nodes_top,
              filtered_behaviors
            )

          :telemetry.execute(
            [:codeqa, :block_impact, :file],
            file_measurements,
            %{path: path}
          )

          {path, Map.put(file_data, "nodes", nodes)}
        end,
        max_concurrency: workers,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.reduce(%{}, fn {:ok, {path, data}}, acc -> Map.put(acc, path, data) end)

    :telemetry.execute(
      [:codeqa, :block_impact, :analyze],
      %{duration: now() - t0},
      %{file_count: map_size(file_results)}
    )

    Map.put(pipeline_result, "files", updated_files)
  end

  defp compute_nodes_timed(
         path,
         content,
         baseline_file_metrics,
         file_results,
         baseline_codebase_cosines,
         nodes_top,
         cached_behaviors
       ) do
    if content == "" do
      {[], %{duration: 0, tokenize_us: 0, parse_us: 0, file_cosines_us: 0, node_count: 0}}
    else
      t0 = now()

      {root_tokens, tokenize_us} = timed(fn -> TokenNormalizer.normalize_structural(content) end)
      {top_level_nodes, parse_us} = timed(fn -> Parser.detect_blocks(root_tokens, Unknown) end)

      baseline_file_agg = FileScorer.file_to_aggregate(baseline_file_metrics)
      language = CodeQA.Language.detect(path).name()

      {baseline_file_cosines, file_cosines_us} =
        timed(fn ->
          SampleRunner.diagnose_aggregate(baseline_file_agg,
            top: 99_999,
            language: language,
            behavior_map: cached_behaviors
          )
        end)

      inc_agg = build_incremental_agg(file_results)
      old_file_triples = file_metrics_to_triples(baseline_file_metrics)
      project_langs = project_languages(file_results)

      node_ctx = %{
        inc_agg: inc_agg,
        old_file_triples: old_file_triples,
        project_langs: project_langs,
        cached_behaviors: cached_behaviors
      }

      nodes =
        top_level_nodes
        |> Enum.map(fn node ->
          serialize_node(
            node,
            path,
            root_tokens,
            baseline_file_cosines,
            baseline_codebase_cosines,
            nodes_top,
            language,
            node_ctx
          )
        end)
        |> Enum.sort_by(fn n -> {n["start_line"], n["column_start"]} end)

      measurements = %{
        duration: now() - t0,
        tokenize_us: tokenize_us,
        parse_us: parse_us,
        file_cosines_us: file_cosines_us,
        node_count: length(top_level_nodes)
      }

      {nodes, measurements}
    end
  end

  defp serialize_node(
         node,
         path,
         root_tokens,
         baseline_file_cosines,
         baseline_codebase_cosines,
         nodes_top,
         language,
         node_ctx
       ) do
    potentials =
      if length(node.tokens) < @min_tokens do
        []
      else
        compute_potentials_timed(
          node,
          path,
          root_tokens,
          baseline_file_cosines,
          baseline_codebase_cosines,
          nodes_top,
          language,
          node_ctx
        )
      end

    children =
      node.children
      |> Enum.map(fn child ->
        serialize_node(
          child,
          path,
          root_tokens,
          baseline_file_cosines,
          baseline_codebase_cosines,
          nodes_top,
          language,
          node_ctx
        )
      end)
      |> Enum.sort_by(fn n -> {n["start_line"], n["column_start"]} end)

    first_token = List.first(node.tokens)
    char_length = Enum.reduce(node.tokens, 0, fn t, acc -> acc + byte_size(t.content) end)

    %{
      "start_line" => node.start_line,
      "end_line" => node.end_line,
      "column_start" => (first_token && first_token.col) || 0,
      "char_length" => char_length,
      "type" => Atom.to_string(node.type),
      "token_count" => length(node.tokens),
      "refactoring_potentials" => potentials,
      "children" => children
    }
  end

  defp compute_potentials_timed(
         %Node{} = node,
         path,
         root_tokens,
         baseline_file_cosines,
         baseline_codebase_cosines,
         nodes_top,
         language,
         node_ctx
       ) do
    t0 = now()

    {reconstructed, reconstruct_us} =
      timed(fn -> FileImpact.reconstruct_without(root_tokens, node) end)

    {without_file_metrics, analyze_file_us} =
      timed(fn -> Analyzer.analyze_file_for_loo(path, reconstructed) end)

    {without_codebase_agg, aggregate_us} =
      timed(fn ->
        new_triples = file_metrics_to_triples(without_file_metrics)

        node_ctx.inc_agg
        |> swap_file_in_agg(node_ctx.old_file_triples, new_triples)
        |> incremental_agg_to_aggregate()
      end)

    {potentials, refactoring_us} =
      timed(fn ->
        RefactoringPotentials.compute(
          baseline_file_cosines,
          without_file_metrics,
          baseline_codebase_cosines,
          without_codebase_agg,
          top: nodes_top,
          language: language,
          languages: node_ctx.project_langs,
          behavior_map: node_ctx.cached_behaviors
        )
      end)

    :telemetry.execute(
      [:codeqa, :block_impact, :node],
      %{
        duration: now() - t0,
        reconstruct_us: reconstruct_us,
        analyze_file_us: analyze_file_us,
        aggregate_us: aggregate_us,
        refactoring_us: refactoring_us
      },
      %{path: path, token_count: length(node.tokens)}
    )

    potentials
  end

  defp file_metrics_to_triples(metrics) when is_map(metrics) do
    metrics
    |> Enum.flat_map(fn {metric_name, metric_data} when is_map(metric_data) ->
      metric_data
      |> Enum.filter(fn {_k, v} -> is_number(v) end)
      |> Enum.map(fn {key, value} -> {metric_name, key, value / 1} end)

      _ -> []
    end)
  end

  defp build_incremental_agg(file_results) do
    file_results
    |> Map.values()
    |> Enum.flat_map(fn file_data ->
      file_data |> Map.get("metrics", %{}) |> file_metrics_to_triples()
    end)
    |> Enum.group_by(fn {metric, key, _val} -> {metric, key} end, fn {_, _, val} -> val end)
    |> Map.new(fn {{metric, key}, values} ->
      n = length(values)
      sum = Enum.sum(values)
      sum_sq = Enum.reduce(values, 0.0, fn v, acc -> acc + v * v end)
      {{metric, key}, %{sum: sum, sum_sq: sum_sq, min: Enum.min(values), max: Enum.max(values), count: n}}
    end)
  end

  defp swap_file_in_agg(inc_agg, old_triples, new_triples) do
    old_map = Map.new(old_triples, fn {metric, key, val} -> {{metric, key}, val} end)
    new_map = Map.new(new_triples, fn {metric, key, val} -> {{metric, key}, val} end)
    all_keys = Enum.uniq(Map.keys(old_map) ++ Map.keys(new_map))

    Enum.reduce(all_keys, inc_agg, fn mk, acc ->
      case Map.get(acc, mk) do
        nil ->
          acc

        state ->
          old_val = Map.get(old_map, mk, 0.0)
          new_val = Map.get(new_map, mk, 0.0)

          Map.put(acc, mk, %{
            sum: state.sum - old_val + new_val,
            sum_sq: state.sum_sq - old_val * old_val + new_val * new_val,
            min: min(state.min, new_val),
            max: max(state.max, new_val),
            count: state.count
          })
      end
    end)
  end

  defp incremental_agg_to_aggregate(inc_agg) do
    Enum.reduce(inc_agg, %{}, fn {{metric, key}, state}, acc ->
      n = state.count
      mean = if n > 0, do: state.sum / n, else: 0.0
      variance = if n > 0, do: max(state.sum_sq / n - mean * mean, 0.0), else: 0.0
      std = :math.sqrt(variance)

      metric_agg = Map.get(acc, metric, %{})

      updated =
        Map.merge(metric_agg, %{
          "mean_#{key}" => Float.round(mean * 1.0, 4),
          "std_#{key}" => Float.round(std * 1.0, 4),
          "min_#{key}" => Float.round(state.min * 1.0, 4),
          "max_#{key}" => Float.round(state.max * 1.0, 4)
        })

      Map.put(acc, metric, updated)
    end)
  end

  defp filter_behaviors_by_languages(behaviors_map, project_langs) do
    Map.new(behaviors_map, fn {category, behaviors} ->
      filtered =
        Enum.filter(behaviors, fn {_behavior, behavior_data} ->
          behavior_langs = Map.get(behavior_data, "_languages", [])
          behavior_langs == [] or Enum.any?(behavior_langs, &(&1 in project_langs))
        end)

      {category, filtered}
    end)
  end

  defp project_languages(path_keyed_map) do
    path_keyed_map
    |> Map.keys()
    |> Enum.map(&CodeQA.Language.detect(&1).name())
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.uniq()
  end

  defp timed(fun) do
    t = now()
    result = fun.()
    {result, now() - t}
  end

  defp now, do: System.monotonic_time(:microsecond)
end
