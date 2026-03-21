defmodule CodeQA.BlockImpactAnalyzer do
  @moduledoc """
  Orchestrates block impact analysis across all files in a pipeline result.

  For each file, tokenizes its content, parses it into a node tree, and for each
  node (recursively including children) computes refactoring potentials via
  leave-one-out impact scoring at both file scope and codebase scope.

  The pipeline result is returned with a `"nodes"` key added to each file entry.
  All other keys in the result are preserved unchanged.
  """

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
  """
  @spec analyze(map(), map(), keyword()) :: map()
  def analyze(pipeline_result, files_map, opts \\ []) do
    nodes_top = Keyword.get(opts, :nodes_top, 3)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    baseline_codebase_agg = Analyzer.analyze_codebase_aggregate(files_map)
    project_langs = project_languages(files_map)

    baseline_codebase_cosines =
      SampleRunner.diagnose_aggregate(baseline_codebase_agg,
        top: 99_999,
        languages: project_langs
      )

    file_results = pipeline_result["files"]

    updated_files =
      file_results
      |> Task.async_stream(
        fn {path, file_data} ->
          content = Map.get(files_map, path, "")
          baseline_file_metrics = Map.get(file_data, "metrics", %{})

          nodes =
            compute_nodes(
              path,
              content,
              baseline_file_metrics,
              file_results,
              baseline_codebase_cosines,
              nodes_top
            )

          {path, Map.put(file_data, "nodes", nodes)}
        end,
        max_concurrency: workers,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.reduce(%{}, fn {:ok, {path, data}}, acc -> Map.put(acc, path, data) end)

    Map.put(pipeline_result, "files", updated_files)
  end

  defp compute_nodes(
         path,
         content,
         baseline_file_metrics,
         file_results,
         baseline_codebase_cosines,
         nodes_top
       ) do
    if content == "" do
      []
    else
      root_tokens = TokenNormalizer.normalize_structural(content)
      top_level_nodes = Parser.detect_blocks(root_tokens, Unknown)

      baseline_file_agg = FileScorer.file_to_aggregate(baseline_file_metrics)
      language = CodeQA.Language.detect(path).name()

      baseline_file_cosines =
        SampleRunner.diagnose_aggregate(baseline_file_agg, top: 99_999, language: language)

      top_level_nodes
      |> Enum.map(fn node ->
        serialize_node(
          node,
          path,
          content,
          root_tokens,
          baseline_file_cosines,
          file_results,
          baseline_codebase_cosines,
          nodes_top,
          language
        )
      end)
      |> Enum.sort_by(fn n -> {n["start_line"], n["column_start"]} end)
    end
  end

  defp serialize_node(
         node,
         path,
         content,
         root_tokens,
         baseline_file_cosines,
         file_results,
         baseline_codebase_cosines,
         nodes_top,
         language
       ) do
    potentials =
      if length(node.tokens) < @min_tokens do
        []
      else
        compute_potentials(
          node,
          path,
          root_tokens,
          baseline_file_cosines,
          file_results,
          baseline_codebase_cosines,
          nodes_top,
          language
        )
      end

    children =
      node.children
      |> Enum.map(fn child ->
        serialize_node(
          child,
          path,
          content,
          root_tokens,
          baseline_file_cosines,
          file_results,
          baseline_codebase_cosines,
          nodes_top,
          language
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

  defp compute_potentials(
         %Node{} = node,
         path,
         root_tokens,
         baseline_file_cosines,
         file_results,
         baseline_codebase_cosines,
         nodes_top,
         language
       ) do
    reconstructed = FileImpact.reconstruct_without(root_tokens, node)
    without_file_metrics = Analyzer.analyze_file(path, reconstructed)

    without_codebase_agg =
      file_results
      |> Map.put(path, %{"metrics" => without_file_metrics})
      |> Analyzer.aggregate_file_metrics()

    project_langs = project_languages(file_results)

    RefactoringPotentials.compute(
      baseline_file_cosines,
      without_file_metrics,
      baseline_codebase_cosines,
      without_codebase_agg,
      top: nodes_top,
      language: language,
      languages: project_langs
    )
  end

  defp project_languages(path_keyed_map) do
    path_keyed_map
    |> Map.keys()
    |> Enum.map(&CodeQA.Language.detect(&1).name())
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.uniq()
  end
end
