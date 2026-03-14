defmodule CodeQA.HealthReport.Grader do
  @moduledoc "Scores metrics and assigns letter grades."

  @doc """
  Score a single metric value (0-100) based on thresholds and direction.

  For `good: :low`, lower values are better (below A threshold = 100).
  For `good: :high`, higher values are better (above A threshold = 100).
  """
  @spec score_metric(map(), number()) :: integer()
  def score_metric(%{good: good, thresholds: t}, value) do
    score =
      if good == :high do
        score_high_is_good(value, t)
      else
        score_low_is_good(value, t)
      end

    clamp(score, 0, 100)
  end

  # Lower values are better: below A = 100, A = 90, A-B = 70-90, etc.
  defp score_low_is_good(val, t) do
    cond do
      val < t.a -> 100
      val == t.a -> 90
      val <= t.b -> interpolate_between(val, t.a, 90, t.b, 70)
      val <= t.c -> interpolate_between(val, t.b, 70, t.c, 50)
      val <= t.d -> interpolate_between(val, t.c, 50, t.d, 30)
      true -> interpolate_below_d(val, t.d, 30)
    end
  end

  # Higher values are better: above A = 100, A = 90, A-B = 70-90, etc.
  # Thresholds are in descending order (a > b > c > d)
  defp score_high_is_good(val, t) do
    cond do
      val > t.a -> 100
      val == t.a -> 90
      val >= t.b -> interpolate_between(val, t.a, 90, t.b, 70)
      val >= t.c -> interpolate_between(val, t.b, 70, t.c, 50)
      val >= t.d -> interpolate_between(val, t.c, 50, t.d, 30)
      true -> interpolate_below_d_high(val, t.d, 30)
    end
  end

  defp interpolate_between(val, bound_a, score_a, bound_b, score_b) do
    range = bound_b - bound_a

    if range == 0 do
      score_a
    else
      ratio = (val - bound_a) / range
      round(score_a + ratio * (score_b - score_a))
    end
  end

  # Value beyond D threshold (low is good): score degrades below 30
  defp interpolate_below_d(_val, threshold_d, _score_at_d) when threshold_d == 0, do: 0

  defp interpolate_below_d(val, threshold_d, score_at_d) do
    overshoot = (val - threshold_d) / threshold_d
    round(Kernel.max(0, score_at_d - overshoot * score_at_d))
  end

  # Value below D threshold (high is good): score degrades below 30
  defp interpolate_below_d_high(_val, threshold_d, _score_at_d) when threshold_d == 0, do: 0

  defp interpolate_below_d_high(val, threshold_d, score_at_d) do
    undershoot = (threshold_d - val) / threshold_d
    round(Kernel.max(0, score_at_d - undershoot * score_at_d))
  end

  defp clamp(val, min_val, max_val), do: val |> Kernel.max(min_val) |> Kernel.min(max_val)

  @doc "Convert a numeric score (0-100) to a letter grade using the given scale."
  @spec grade_letter(number(), [{number(), String.t()}]) :: String.t()
  def grade_letter(score, scale \\ CodeQA.HealthReport.Categories.default_grade_scale()) do
    Enum.find_value(scale, "F", fn {min, letter} ->
      if score >= min, do: letter
    end)
  end

  @doc """
  Grade a category by computing weighted average of its metric scores.
  Returns `%{key, name, score, grade, metric_scores}`.
  """
  @spec grade_category(map(), map(), [{number(), String.t()}]) :: map()
  def grade_category(
        category,
        file_metrics,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale()
      ) do
    scored =
      category.metrics
      |> Enum.map(fn metric_def ->
        value = get_in(file_metrics, [metric_def.source, metric_def.name])

        if value do
          %{
            name: metric_def.name,
            source: metric_def.source,
            weight: metric_def.weight,
            value: value,
            score: score_metric(metric_def, value)
          }
        end
      end)
      |> Enum.reject(&is_nil/1)

    total_weight = Enum.reduce(scored, 0.0, fn s, acc -> acc + s.weight end)

    score =
      if total_weight > 0 do
        weighted = Enum.reduce(scored, 0.0, fn s, acc -> acc + s.score * s.weight end)
        round(weighted / total_weight)
      else
        0
      end

    %{
      key: category.key,
      name: category.name,
      score: score,
      grade: grade_letter(score, scale),
      metric_scores: scored
    }
  end

  @doc """
  Grade a file's metrics against all categories.
  `file_metrics` is the `%{"entropy" => %{...}, "halstead" => %{...}}` map from analysis.
  """
  @spec grade_file(list(), map(), [{number(), String.t()}]) :: list()
  def grade_file(
        categories,
        file_metrics,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale()
      ) do
    Enum.map(categories, &grade_category(&1, file_metrics, scale))
  end

  @doc """
  Grade codebase aggregate metrics. Uses mean_ values from aggregate.
  """
  @spec grade_aggregate(list(), map(), [{number(), String.t()}]) :: list()
  def grade_aggregate(
        categories,
        aggregate,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale()
      ) do
    # Convert aggregate format (mean_X keys) to file-metric-like format
    file_like =
      Map.new(aggregate, fn {source, stats} ->
        values =
          stats
          |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "mean_") end)
          |> Map.new(fn {"mean_" <> key, v} -> {key, v} end)

        {source, values}
      end)

    Enum.map(categories, &grade_category(&1, file_like, scale))
  end

  @doc "Compute overall score as average of category scores."
  @spec overall_score(list(), [{number(), String.t()}]) :: {integer(), String.t()}
  def overall_score(
        category_grades,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale()
      ) do
    if category_grades == [] do
      {0, "F"}
    else
      avg =
        Enum.reduce(category_grades, 0, fn g, acc -> acc + g.score end)
        |> div(length(category_grades))

      {avg, grade_letter(avg, scale)}
    end
  end

  @doc """
  Find worst offender files for a category. Returns top N files sorted by worst score.
  `all_file_metrics` is `%{"path" => %{"metrics" => %{...}}}` from analysis results.
  """
  @spec worst_offenders(map(), map(), integer(), [{number(), String.t()}]) :: list()
  def worst_offenders(
        category,
        all_file_metrics,
        top_n,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale()
      ) do
    all_file_metrics
    |> Enum.map(fn {path, file_data} ->
      metrics = Map.get(file_data, "metrics", %{})
      graded = grade_category(category, metrics, scale)
      %{
        path: path,
        score: graded.score,
        grade: graded.grade,
        metric_scores: graded.metric_scores,
        lines: file_data["lines"],
        bytes: file_data["bytes"]
      }
    end)
    |> Enum.filter(fn f -> f.metric_scores != [] end)
    |> Enum.sort_by(& &1.score, :asc)
    |> Enum.take(top_n)
  end
end
