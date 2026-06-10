defmodule CodeQA.BlockImpactAnalyzer do
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken
  alias CodeQA.Language

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
  alias CodeQA.AST.Classification.NodeClassifier
  alias CodeQA.AST.Classification.TypedNodeKind
  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.BlockImpact.FileImpact
  alias CodeQA.BlockImpact.RefactoringPotentials
  alias CodeQA.CombinedMetrics.FileScorer
  alias CodeQA.CombinedMetrics.SampleRunner
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Languages.Unknown
  import CodeQA.Shared, only: [project_languages_shared: 1]

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
    # When set, per-node leave-one-out is computed only for these paths (the PR's
    # changed files). The codebase aggregate and baseline cosines below are still
    # built from every file, so the codebase scope and overall grade are
    # unaffected — only the per-file node computation, whose output is read for
    # changed files alone, is skipped for the rest. `nil` means all files.
    node_paths = Keyword.get(opts, :node_paths)
    # Files larger than this byte cap skip per-node leave-one-out entirely. LOO
    # is O(file_bytes) per node, so a few large/generated files (lockfiles,
    # bundled assets) dominate the run. They still flow into the codebase
    # aggregate — only their refactoring nodes are dropped. `nil` means no cap.
    max_loo_file_bytes = Keyword.get(opts, :max_loo_file_bytes)

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
    node_path_set = node_paths && MapSet.new(node_paths)

    # The incremental aggregate and project languages are identical for every
    # file, so they're built once here. Building them per file (over all
    # file_results) was O(files^2) and dominated large-repo runs.
    inc_agg = build_incremental_agg(file_results)
    project_langs = project_languages(file_results)

    # Phase A — prepare each file (tokenize, parse, file cosines, index the node
    # tree). Cheap; parallelized over files. Produces the per-file indexed tree
    # plus the work units, which are pooled across all files in phase B.
    preps =
      file_results
      |> Task.async_stream(
        fn {path, file_data} ->
          content = node_content(path, files_map, node_path_set, max_loo_file_bytes)

          prepare_file(path, content, file_data, baseline_codebase_cosines,
            nodes_top: nodes_top,
            cached_behaviors: filtered_behaviors,
            inc_agg: inc_agg,
            project_langs: project_langs
          )
        end,
        max_concurrency: workers,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, prep} -> prep end)

    # The per-file node_ctx is large (file content, tokens, cosines). Held in a
    # map keyed by file path and captured once per Flow stage, it is copied
    # O(stages) times — not once per node, which at thousands of nodes drove
    # memory into tens of GB and a hard slowdown cliff.
    ctx_by_file = Map.new(preps, fn prep -> {prep.path, prep.node_ctx} end)

    # Phase B — compute every node of every file in ONE shared pool, so a few
    # large files (hundreds of nodes each) can't leave most cores idle while
    # they grind serially. Flow's `max_demand` bounds in-flight units per stage,
    # giving backpressure so the whole unit set isn't materialized at once.
    # Units are independent; keyed by their stable index path for exact tree
    # reconstruction.
    work =
      preps
      |> Enum.flat_map(& &1.units)
      |> Flow.from_enumerable(max_demand: 5, stages: workers)
      |> Flow.map(fn unit -> {unit.id, compute_unit(unit, ctx_by_file)} end)
      |> Map.new()

    # Phase C — rebuild each file's node tree from the pooled results and emit
    # per-file telemetry. Cheap and serial.
    updated_files =
      preps
      |> Map.new(fn prep -> finalize_file(prep, work) end)

    :telemetry.execute(
      [:codeqa, :block_impact, :analyze],
      %{duration: now() - t0},
      %{file_count: map_size(file_results)}
    )

    Map.put(pipeline_result, "files", updated_files)
  end

  # Returns a file's content for node computation, or "" to skip it. A file is
  # skipped if it's out of the changed-file scope OR over the byte cap. Either
  # way compute_nodes_timed short-circuits to no nodes, skipping the expensive
  # per-node leave-one-out while leaving the codebase aggregate untouched.
  defp node_content(path, files_map, scope_set, max_bytes) do
    if scope_set && not MapSet.member?(scope_set, path) do
      ""
    else
      cap_by_bytes(Map.get(files_map, path, ""), max_bytes)
    end
  end

  defp cap_by_bytes(content, nil), do: content

  defp cap_by_bytes(content, max_bytes) when byte_size(content) > max_bytes, do: ""

  defp cap_by_bytes(content, _max_bytes), do: content

  # Phase A — tokenize, parse, file cosines, and index the node tree into flat
  # work units. A skipped file (out of scope / over byte cap) yields no units
  # and an empty indexed tree. The returned prep carries everything phase C
  # needs to rebuild the file's nodes after the units are computed in phase B.
  defp prepare_file(path, "", file_data, _cosines, _opts) do
    %{
      path: path,
      file_data: file_data,
      node_ctx: nil,
      indexed_tree: [],
      units: [],
      measurements: %{duration: 0, file_cosines_us: 0, node_count: 0, parse_us: 0, tokenize_us: 0}
    }
  end

  defp prepare_file(path, content, file_data, baseline_codebase_cosines, opts) do
    nodes_top = Keyword.fetch!(opts, :nodes_top)
    cached_behaviors = Keyword.fetch!(opts, :cached_behaviors)
    inc_agg = Keyword.fetch!(opts, :inc_agg)
    project_langs = Keyword.fetch!(opts, :project_langs)
    baseline_file_metrics = Map.get(file_data, "metrics", %{})

    {root_tokens, tokenize_us} = timed(fn -> TokenNormalizer.normalize_structural(content) end)
    {top_level_nodes, parse_us} = timed(fn -> Parser.detect_blocks(root_tokens, Unknown) end)

    baseline_file_agg = FileScorer.file_to_aggregate(baseline_file_metrics)
    lang_mod = Language.detect(path)
    language = lang_mod.name()

    {baseline_file_cosines, file_cosines_us} =
      timed(fn ->
        SampleRunner.diagnose_aggregate(baseline_file_agg,
          top: 99_999,
          language: language,
          behavior_map: cached_behaviors
        )
      end)

    node_ctx = %{
      baseline_codebase_cosines: baseline_codebase_cosines,
      baseline_file_cosines: baseline_file_cosines,
      baseline_file_metrics: baseline_file_metrics,
      cached_behaviors: cached_behaviors,
      content: content,
      inc_agg: inc_agg,
      lang_mod: lang_mod,
      language: language,
      nodes_top: nodes_top,
      old_file_triples: file_metrics_to_triples(baseline_file_metrics),
      path: path,
      project_langs: project_langs
    }

    # The index path is prefixed with `path` so unit ids are globally unique
    # across files — units of all files share one work pool, where a file-local
    # index alone would collide (every file has a top-level node at index 0).
    indexed_tree = index_tree(top_level_nodes, path, nil, [path])

    %{
      path: path,
      file_data: file_data,
      node_ctx: node_ctx,
      indexed_tree: indexed_tree,
      units: flatten_units(indexed_tree),
      measurements: %{
        bytes: byte_size(content),
        file_cosines_us: file_cosines_us,
        node_count: length(top_level_nodes),
        parse_us: parse_us,
        token_count: length(root_tokens),
        tokenize_us: tokenize_us
      }
    }
  end

  # Phase C — rebuild a file's node tree from the pooled work results and emit
  # per-file telemetry. The per-file `duration` is the sum of its nodes' own
  # durations (not wall-clock — nodes run in the shared phase-B pool now).
  defp finalize_file(%{path: path, file_data: file_data} = prep, work) do
    nodes = rebuild_nodes(prep.indexed_tree, work)

    node_duration_sum =
      prep.units
      |> Enum.map(fn unit -> work |> Map.get(unit.id) |> unit_node_duration() end)
      |> Enum.sum()

    measurements = Map.put(prep.measurements, :duration, node_duration_sum)
    :telemetry.execute([:codeqa, :block_impact, :file], measurements, %{path: path})

    {path, Map.put(file_data, "nodes", nodes)}
  end

  defp unit_node_duration({_block_type, _potentials, node_us}), do: node_us

  # Wraps each node with a stable index path (its position in the pre-order
  # tree), its resolved parent_context, and its owning file's key — preserving
  # the children structure. The node_ctx is NOT carried per unit: it is large
  # (file content, tokens, cosines) and would be copied once per node when units
  # are dispatched to the Flow workers, blowing up memory. Instead units carry
  # only `file_key`, and the worker looks the node_ctx up from a per-file map
  # captured once per stage. Each node's parent_context is resolved by its
  # parent before the recursive call, exactly as the original recursion did;
  # top-level nodes get `nil`. The index path is deterministic and
  # order-independent, so work can be computed in any order and rebuilt exactly.
  defp index_tree(nodes, file_key, parent_tokens, prefix) do
    nodes
    |> Enum.with_index()
    |> Enum.map(fn {node, i} ->
      id = prefix ++ [i]
      parent_context = if parent_tokens, do: parent_context_for(parent_tokens, node)

      %{
        id: id,
        node: node,
        file_key: file_key,
        parent_context: parent_context,
        children: index_tree(node.children, file_key, node.tokens, id)
      }
    end)
  end

  defp flatten_units(indexed) do
    Enum.flat_map(indexed, fn unit ->
      [Map.delete(unit, :children) | flatten_units(unit.children)]
    end)
  end

  # The expensive, independent per-node work: classify + leave-one-out
  # potentials. Reads only the node and the read-only node_ctx, so units can be
  # computed in parallel across files. Returns the node's own duration so phase
  # C can sum it into the per-file telemetry.
  defp compute_unit(
         %{node: node, file_key: file_key, parent_context: parent_context},
         ctx_by_file
       ) do
    node_ctx = Map.fetch!(ctx_by_file, file_key)

    block_type =
      node
      |> NodeClassifier.classify(node_ctx.lang_mod, parent_context)
      |> TypedNodeKind.of()

    {potentials, node_us} =
      if length(node.tokens) < @min_tokens do
        {[], 0}
      else
        compute_potentials_timed(node, node_ctx, block_type)
      end

    {block_type, potentials, node_us}
  end

  defp rebuild_nodes(indexed, work) do
    indexed
    |> Enum.map(&rebuild_node(&1, work))
    |> Enum.sort_by(fn n -> {n["start_line"], n["column_start"]} end)
  end

  defp rebuild_node(%{id: id, node: node, children: children}, work) do
    {block_type, potentials, _node_us} = Map.fetch!(work, id)

    first_token = List.first(node.tokens)
    char_length = node.tokens |> Enum.sum_by(fn t -> byte_size(t.content) end)

    %{
      "start_line" => node.start_line,
      "end_line" => node.end_line,
      "column_start" => (first_token && first_token.col) || 0,
      "char_length" => char_length,
      "type" => Atom.to_string(block_type),
      "token_count" => length(node.tokens),
      "refactoring_potentials" => potentials,
      "children" => rebuild_nodes(children, work)
    }
  end

  # Returns the parent's tokens that come strictly before `child`'s first token,
  # bounded to the same source line (everything since the last newline) and with
  # leading whitespace stripped so the classification signals see the keyword at
  # indent 0. Lets NodeClassifier see the keyword that drove the bracket-split
  # (`alias`, `@name`, etc.) when classifying a sub-block.
  defp parent_context_for(parent_tokens, child),
    do: List.first(child.tokens) |> tokens_before_child(parent_tokens)

  defp compute_potentials_timed(%Node{} = node, node_ctx, block_type) do
    t0 = now()

    {{block_content, reconstructed}, reconstruct_us} =
      timed(fn -> FileImpact.slice_without_original(node_ctx.content, node) end)

    {without_file_metrics, analyze_file_us} =
      timed(fn ->
        Analyzer.analyze_file_for_loo_partial(
          node_ctx.path,
          reconstructed,
          node_ctx.baseline_file_metrics,
          block_content
        )
      end)

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
          node_ctx.baseline_file_cosines,
          without_file_metrics,
          node_ctx.baseline_codebase_cosines,
          without_codebase_agg,
          top: node_ctx.nodes_top,
          language: node_ctx.language,
          languages: node_ctx.project_langs,
          behavior_map: node_ctx.cached_behaviors,
          block_type: block_type
        )
      end)

    duration = now() - t0

    :telemetry.execute(
      [:codeqa, :block_impact, :node],
      %{
        aggregate_us: aggregate_us,
        analyze_file_us: analyze_file_us,
        duration: duration,
        reconstruct_us: reconstruct_us,
        refactoring_us: refactoring_us
      },
      %{path: node_ctx.path, token_count: length(node.tokens)}
    )

    {potentials, duration}
  end

  defp file_metrics_to_triples(metrics) when is_map(metrics) do
    metrics
    |> Enum.flat_map(fn
      {metric_name, metric_data} when is_map(metric_data) ->
        metric_data
        |> Enum.filter(fn {_k, v} -> is_number(v) end)
        |> Enum.map(fn {key, value} -> {metric_name, key, value / 1} end)

      _ ->
        []
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
      sum = values |> Enum.sum()
      sum_sq = values |> Enum.reduce(0.0, fn v, acc -> acc + v * v end)

      {{metric, key},
       %{count: n, max: values |> Enum.max(), min: values |> Enum.min(), sum: sum, sum_sq: sum_sq}}
    end)
  end

  defp swap_file_in_agg(inc_agg, old_triples, new_triples) do
    old_map =
      for {metric, key, val} <- old_triples do
        {{metric, key}, val}
      end
      |> Map.new()

    new_map =
      for {metric, key, val} <- new_triples do
        {{metric, key}, val}
      end
      |> Map.new()

    all_keys = (Map.keys(old_map) ++ Map.keys(new_map)) |> Enum.uniq()

    all_keys
    |> Enum.reduce(inc_agg, fn mk, acc ->
      case Map.get(acc, mk) do
        nil ->
          acc

        state ->
          old_val = Map.get(old_map, mk, 0.0)
          new_val = Map.get(new_map, mk, 0.0)

          Map.put(acc, mk, %{
            count: state.count,
            max: max(state.max, new_val),
            min: min(state.min, new_val),
            sum: state.sum - old_val + new_val,
            sum_sq: state.sum_sq - old_val * old_val + new_val * new_val
          })
      end
    end)
  end

  defp incremental_agg_to_aggregate(inc_agg) do
    inc_agg
    |> Enum.reduce(%{}, fn {{metric, key}, state}, acc ->
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
        behaviors
        |> Enum.filter(fn {_behavior, behavior_data} ->
          behavior_langs = Map.get(behavior_data, "_languages", [])
          behavior_langs == [] or Enum.any?(behavior_langs, &(&1 in project_langs))
        end)

      {category, filtered}
    end)
  end

  defp project_languages(path_keyed_map), do: project_languages_shared(path_keyed_map)

  defp timed(fun) do
    t = now()
    result = fun.()
    {result, now() - t}
  end

  defp now, do: System.monotonic_time(:microsecond)

  defp tokens_before_child(nil, _parent_tokens), do: []

  defp tokens_before_child(child_first, parent_tokens) do
    nl_kind = NewlineToken.kind()
    ws_kind = WhitespaceToken.kind()

    parent_tokens
    |> Enum.take_while(&(&1 != child_first))
    |> Enum.reverse()
    |> Enum.take_while(&(&1.kind != nl_kind))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1.kind == ws_kind))
  end
end
