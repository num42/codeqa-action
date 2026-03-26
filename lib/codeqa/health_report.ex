defmodule CodeQA.HealthReport do
  @moduledoc "Orchestrates health report generation from analysis results."

  alias CodeQA.CombinedMetrics.{FileScorer, SampleRunner}
  alias CodeQA.HealthReport.{Config, Delta, Formatter, Grader, TopBlocks}

  @spec generate(map(), keyword()) :: map()
  def generate(analysis_results, opts \\ []) do
    config_path = Keyword.get(opts, :config)
    base_results = Keyword.get(opts, :base_results)
    changed_files = Keyword.get(opts, :changed_files, [])

    %{
      categories: categories,
      grade_scale: grade_scale,
      impact_map: impact_map,
      combined_top: combined_top,
      block_min_lines: block_min_lines,
      block_max_lines: block_max_lines
    } =
      Config.load(config_path)

    aggregate = get_in(analysis_results, ["codebase", "aggregate"]) || %{}
    files = Map.get(analysis_results, "files", %{})
    project_langs = project_languages(files)

    threshold_grades =
      categories
      |> Grader.grade_aggregate(aggregate, grade_scale)
      |> Enum.zip(categories)
      |> Enum.map(fn {graded, _cat_def} ->
        summary = build_category_summary(graded)

        graded
        |> Map.put(:type, :threshold)
        |> Map.merge(%{summary: summary, worst_offenders: []})
      end)

    worst_files_map = FileScorer.worst_files_per_behavior(files, combined_top: combined_top)

    all_cosines =
      SampleRunner.diagnose_aggregate(aggregate, top: 99_999, languages: project_langs)

    cosines_by_category = Enum.group_by(all_cosines, & &1.category)

    cosine_grades =
      Grader.grade_cosine_categories(cosines_by_category, worst_files_map, grade_scale)

    all_categories =
      (threshold_grades ++ cosine_grades)
      |> Enum.map(fn cat ->
        Map.put(cat, :impact, Map.get(impact_map, to_string(cat.key), 1))
      end)

    {overall_score, overall_grade} = Grader.overall_score(all_categories, grade_scale, impact_map)

    metadata = build_metadata(analysis_results)

    top_issues = Enum.take(all_cosines, 10)

    codebase_cosine_lookup =
      Map.new(all_cosines, fn i -> {{i.category, i.behavior}, i.cosine} end)

    top_blocks =
      TopBlocks.build(analysis_results, changed_files, codebase_cosine_lookup,
        block_min_lines: block_min_lines,
        block_max_lines: block_max_lines
      )

    grading_cfg = %{
      category_defs: categories,
      grade_scale: grade_scale,
      impact_map: impact_map,
      combined_top: combined_top
    }

    {codebase_delta, pr_summary} =
      if base_results do
        build_delta_and_summary(
          base_results,
          analysis_results,
          overall_score,
          overall_grade,
          grading_cfg,
          changed_files,
          top_blocks
        )
      else
        {nil, nil}
      end

    %{
      metadata: metadata,
      pr_summary: pr_summary,
      overall_score: overall_score,
      overall_grade: overall_grade,
      codebase_delta: codebase_delta,
      categories: all_categories,
      top_issues: top_issues,
      top_blocks: top_blocks
    }
  end

  @spec to_markdown(map(), atom(), atom()) :: String.t()
  def to_markdown(report, detail \\ :default, format \\ :plain) do
    Formatter.format_markdown(report, detail, format)
  end

  defp build_delta_and_summary(
         base_results,
         head_results,
         head_score,
         head_grade,
         %{
           category_defs: category_defs,
           grade_scale: grade_scale,
           impact_map: impact_map,
           combined_top: combined_top
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
      |> Enum.map(fn cat ->
        Map.put(cat, :impact, Map.get(impact_map, to_string(cat.key), 1))
      end)

    {base_score, base_grade} = Grader.overall_score(base_all_categories, grade_scale, impact_map)

    blocks_flagged = length(top_blocks)
    files_added = Enum.count(changed_files, &(&1.status == "added"))
    files_modified = Enum.count(changed_files, &(&1.status == "modified"))

    summary = %{
      base_score: base_score,
      head_score: head_score,
      score_delta: head_score - base_score,
      base_grade: base_grade,
      head_grade: head_grade,
      blocks_flagged: blocks_flagged,
      files_changed: length(changed_files),
      files_added: files_added,
      files_modified: files_modified
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

  defp project_languages(files_map) do
    files_map
    |> Map.keys()
    |> Enum.map(&CodeQA.Language.detect(&1).name())
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.uniq()
  end

  defp build_category_summary(%{type: :cosine}), do: ""

  defp build_category_summary(graded) do
    low_scorers =
      graded.metric_scores
      |> Enum.filter(fn m -> m.score < 60 end)
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
