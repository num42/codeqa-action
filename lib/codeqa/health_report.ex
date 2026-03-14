defmodule CodeQA.HealthReport do
  @moduledoc "Orchestrates health report generation from analysis results."

  alias CodeQA.HealthReport.{Config, Grader, Formatter}

  @spec generate(map(), keyword()) :: map()
  def generate(analysis_results, opts \\ []) do
    config_path = Keyword.get(opts, :config)
    detail = Keyword.get(opts, :detail, :default)
    top_n = Keyword.get(opts, :top, 5)

    %{categories: categories, grade_scale: grade_scale} = Config.load(config_path)
    aggregate = get_in(analysis_results, ["codebase", "aggregate"]) || %{}
    files = Map.get(analysis_results, "files", %{})

    category_grades = Grader.grade_aggregate(categories, aggregate, grade_scale)

    category_grades =
      Enum.zip(categories, category_grades)
      |> Enum.map(fn {cat_def, graded} ->
        summary = build_category_summary(graded)

        cat_top = Map.get(cat_def, :top, top_n)

        worst =
          case detail do
            :summary -> []
            :full -> Grader.worst_offenders(cat_def, files, map_size(files), grade_scale)
            _default -> Grader.worst_offenders(cat_def, files, cat_top, grade_scale)
          end

        Map.merge(graded, %{summary: summary, worst_offenders: worst})
      end)

    {overall_score, overall_grade} = Grader.overall_score(category_grades, grade_scale)

    metadata = build_metadata(analysis_results)

    %{
      metadata: metadata,
      overall_score: overall_score,
      overall_grade: overall_grade,
      categories: category_grades
    }
  end

  @spec to_markdown(map(), atom(), atom(), keyword()) :: String.t()
  def to_markdown(report, detail \\ :default, format \\ :plain, opts \\ []) do
    Formatter.format_markdown(report, detail, format, opts)
  end

  defp build_metadata(analysis_results) do
    meta = Map.get(analysis_results, "metadata", %{})

    %{
      path: meta["path"] || "unknown",
      timestamp: meta["timestamp"] || DateTime.utc_now() |> DateTime.to_iso8601(),
      total_files: meta["total_files"] || map_size(Map.get(analysis_results, "files", %{}))
    }
  end

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
