defmodule CodeQA.HealthReport do
  @moduledoc "Orchestrates health report generation from analysis results."

  alias CodeQA.CombinedMetrics.FileScorer
  alias CodeQA.CombinedMetrics.SampleRunner
  alias CodeQA.HealthReport.Config
  alias CodeQA.HealthReport.Delta
  alias CodeQA.HealthReport.Formatter
  alias CodeQA.HealthReport.Grader
  alias CodeQA.HealthReport.TopBlocks
  import CodeQA.Shared, only: [project_languages_shared: 1]

  @spec generate(map(), keyword()) :: map()
  def generate(analysis_results, opts \\ []) do
    view = Keyword.get(opts, :view, :both)
    config = Config.load(Keyword.get(opts, :config))

    aggregate = get_in(analysis_results, ["codebase", "aggregate"]) || %{}
    files = Map.get(analysis_results, "files", %{})

    metrics = if view in [:metrics, :both], do: build_metrics(aggregate, files, config), else: %{}

    actions =
      if view in [:actions, :both], do: build_actions(analysis_results, config, opts), else: %{}

    base = %{metadata: build_metadata(analysis_results)}

    base
    |> Map.merge(metrics)
    |> Map.merge(actions)
    |> put_delta_and_summary(analysis_results, metrics, actions, config, opts)
  end

  # Numberified metric scales: threshold + cosine grades, overall, top issues.
  # No block work — TopBlocks and codebase_cosine_lookup are skipped entirely.
  defp build_metrics(aggregate, files, config) do
    %{
      categories: categories,
      combined_top: combined_top,
      grade_scale: grade_scale,
      impact_map: impact_map
    } =
      config

    project_langs = project_languages(files)

    threshold_grades =
      categories
      |> Grader.grade_aggregate(aggregate, grade_scale)
      |> Enum.zip(categories)
      |> Enum.map(fn {graded, _cat_def} ->
        graded
        |> Map.put(:type, :threshold)
        |> Map.merge(%{summary: build_category_summary(graded), worst_offenders: []})
      end)

    worst_files_map = FileScorer.worst_files_per_behavior(files, combined_top: combined_top)

    all_cosines =
      SampleRunner.diagnose_aggregate(aggregate, top: 99_999, languages: project_langs)

    cosines_by_category = Enum.group_by(all_cosines, & &1.category)

    cosine_grades =
      Grader.grade_cosine_categories(cosines_by_category, worst_files_map, grade_scale)

    all_categories =
      (threshold_grades ++ cosine_grades)
      |> Enum.map(&Map.put(&1, :impact, Map.get(impact_map, to_string(&1.key), 1)))

    {overall_score, overall_grade} = Grader.overall_score(all_categories, grade_scale, impact_map)

    %{
      categories: all_categories,
      overall_grade: overall_grade,
      overall_score: overall_score,
      top_issues: Enum.take(all_cosines, 10)
    }
  end

  # Agent-actionable blocks: only the cosine lookup feeding TopBlocks is built.
  # FileScorer, grading and overall score are skipped — none reach the prompt.
  defp build_actions(analysis_results, config, opts) do
    aggregate = get_in(analysis_results, ["codebase", "aggregate"]) || %{}
    files = Map.get(analysis_results, "files", %{})
    project_langs = project_languages(files)
    changed_files = Keyword.get(opts, :changed_files, [])

    all_cosines =
      SampleRunner.diagnose_aggregate(aggregate, top: 99_999, languages: project_langs)

    codebase_cosine_lookup =
      Map.new(all_cosines, fn i -> {{i.category, i.behavior}, i.cosine} end)

    block_opts = [
      block_min_lines: config.block_min_lines,
      block_max_lines: config.block_max_lines,
      diff_line_ranges: Keyword.get(opts, :diff_line_ranges, %{})
    ]

    %{
      top_blocks:
        TopBlocks.build(analysis_results, changed_files, codebase_cosine_lookup, block_opts),
      worst_blocks_by_category:
        TopBlocks.worst_per_category(
          analysis_results,
          changed_files,
          codebase_cosine_lookup,
          block_opts
        )
    }
  end

  # Delta needs both metric grades (head + base) and the block list; only the
  # `:both`/`:metrics`+base path provides metrics, so guard on its presence.
  defp put_delta_and_summary(report, _analysis, metrics, _actions, _config, _opts)
       when metrics == %{},
       do: Map.merge(report, %{codebase_delta: nil, pr_summary: nil})

  defp put_delta_and_summary(report, analysis_results, metrics, actions, config, opts) do
    base_results = Keyword.get(opts, :base_results)
    top_blocks = Map.get(actions, :top_blocks, [])

    {codebase_delta, pr_summary} =
      if base_results do
        grading_cfg = %{
          category_defs: config.categories,
          combined_top: config.combined_top,
          grade_scale: config.grade_scale,
          impact_map: config.impact_map
        }

        build_delta_and_summary(
          base_results,
          analysis_results,
          metrics.overall_score,
          metrics.overall_grade,
          grading_cfg,
          Keyword.get(opts, :changed_files, []),
          top_blocks
        )
      else
        {nil, nil}
      end

    Map.merge(report, %{codebase_delta: codebase_delta, pr_summary: pr_summary})
  end

  @spec to_markdown(map(), atom(), atom(), atom()) :: String.t()
  def to_markdown(report, detail \\ :default, format \\ :plain, view \\ :both),
    do: report |> Formatter.format_markdown(detail, format, view)

  defp build_delta_and_summary(
         base_results,
         head_results,
         head_score,
         head_grade,
         %{
           category_defs: category_defs,
           combined_top: combined_top,
           grade_scale: grade_scale,
           impact_map: impact_map
         },
         changed_files,
         top_blocks
       ) do
    delta = Delta.compute(base_results, head_results)

    base_aggregate = get_in(base_results, ["codebase", "aggregate"]) || %{}
    base_files = Map.get(base_results, "files", %{})
    base_project_langs = project_languages(base_files)

    base_threshold_grades =
      category_defs
      |> Grader.grade_aggregate(base_aggregate, grade_scale)
      |> Enum.zip(category_defs)
      |> Enum.map(fn {graded, _cat_def} ->
        graded
        |> Map.put(:type, :threshold)
        |> Map.merge(%{summary: "", worst_offenders: []})
      end)

    base_worst_files_map =
      FileScorer.worst_files_per_behavior(base_files, combined_top: combined_top)

    base_cosines_by_category =
      SampleRunner.diagnose_aggregate(base_aggregate, top: 99_999, languages: base_project_langs)
      |> Enum.group_by(& &1.category)

    base_cosine_grades =
      Grader.grade_cosine_categories(
        base_cosines_by_category,
        base_worst_files_map,
        grade_scale
      )

    base_all_categories =
      (base_threshold_grades ++ base_cosine_grades)
      |> Enum.map(&Map.put(&1, :impact, Map.get(impact_map, to_string(&1.key), 1)))

    {base_score, base_grade} = Grader.overall_score(base_all_categories, grade_scale, impact_map)

    blocks_flagged = length(top_blocks)
    files_added = changed_files |> Enum.count(&(&1.status == "added"))
    files_modified = changed_files |> Enum.count(&(&1.status == "modified"))

    summary = %{
      base_grade: base_grade,
      base_score: base_score,
      blocks_flagged: blocks_flagged,
      files_added: files_added,
      files_changed: length(changed_files),
      files_modified: files_modified,
      head_grade: head_grade,
      head_score: head_score,
      score_delta: head_score - base_score
    }

    {delta, summary}
  end

  defp build_metadata(analysis_results) do
    meta = Map.get(analysis_results, "metadata", %{})

    %{
      path: meta["path"] || "unknown",
      timestamp: meta["timestamp"] || DateTime.utc_now() |> DateTime.to_iso8601(),
      total_files: meta["total_files"] || map_size(Map.get(analysis_results, "files", %{}))
    }
  end

  defp project_languages(files_map), do: project_languages_shared(files_map)

  defp build_category_summary(%{type: :cosine}), do: ""

  defp build_category_summary(graded) do
    low_scorers =
      graded.metric_scores
      |> Enum.filter(&(&1.score < 60))
      |> length()

    cond do
      graded.score >= 90 -> "Excellent"
      graded.score >= 70 and low_scorers == 0 -> "Good"
      graded.score >= 70 -> "Good overall, #{low_scorers} metric(s) need attention"
      graded.score >= 50 -> "Needs improvement"
      true -> "Critical — requires attention"
    end
  end
end
