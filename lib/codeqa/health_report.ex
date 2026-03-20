defmodule CodeQA.HealthReport do
  @moduledoc "Orchestrates health report generation from analysis results."

  alias CodeQA.HealthReport.{Config, Grader, Formatter}
  alias CodeQA.CombinedMetrics.{FileScorer, SampleRunner}

  @spec generate(map(), keyword()) :: map()
  def generate(analysis_results, opts \\ []) do
    config_path = Keyword.get(opts, :config)
    detail = Keyword.get(opts, :detail, :default)
    top_n = Keyword.get(opts, :top, 5)

    %{
      categories: categories,
      grade_scale: grade_scale,
      impact_map: impact_map,
      combined_top: combined_top
    } =
      Config.load(config_path)

    aggregate = get_in(analysis_results, ["codebase", "aggregate"]) || %{}
    files = Map.get(analysis_results, "files", %{})
    project_langs = project_languages(files)

    threshold_grades =
      categories
      |> Grader.grade_aggregate(aggregate, grade_scale)
      |> Enum.zip(categories)
      |> Enum.map(fn {graded, cat_def} ->
        summary = build_category_summary(graded)
        cat_top = Map.get(cat_def, :top, top_n)

        worst =
          case detail do
            :summary -> []
            :full -> Grader.worst_offenders(cat_def, files, map_size(files), grade_scale)
            _default -> Grader.worst_offenders(cat_def, files, cat_top, grade_scale)
          end

        graded
        |> Map.put(:type, :threshold)
        |> Map.merge(%{summary: summary, worst_offenders: worst})
      end)

    worst_files_map = FileScorer.worst_files_per_behavior(files, combined_top: combined_top)

    cosine_grades = Grader.grade_cosine_categories(aggregate, worst_files_map, grade_scale, project_langs)

    # TODO(option-c): a unified flat issues list would replace the current per-category worst offenders loop; all category results would be flattened, deduplicated by file+line, and re-ranked by a cross-category severity score before rendering.
    all_categories =
      (threshold_grades ++ cosine_grades)
      |> Enum.map(fn cat ->
        Map.put(cat, :impact, Map.get(impact_map, to_string(cat.key), 1))
      end)

    {overall_score, overall_grade} = Grader.overall_score(all_categories, grade_scale, impact_map)

    metadata = build_metadata(analysis_results)

    top_issues = SampleRunner.diagnose_aggregate(aggregate, top: 10, languages: project_langs)

    %{
      metadata: metadata,
      overall_score: overall_score,
      overall_grade: overall_grade,
      categories: all_categories,
      top_issues: top_issues
    }
  end

  @spec to_markdown(map(), atom(), atom()) :: String.t()
  def to_markdown(report, detail \\ :default, format \\ :plain) do
    Formatter.format_markdown(report, detail, format)
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
