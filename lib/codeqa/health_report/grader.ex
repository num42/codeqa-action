defmodule CodeQA.HealthReport.Grader do
  @moduledoc "Scores metrics and assigns letter grades."

  alias CodeQA.CombinedMetrics.SampleRunner

  @doc """
  Score a single metric value (0-100) based on thresholds and direction.

  For `good: :low`, lower values are better (below A threshold = 100).
  For `good: :high`, higher values are better (above A threshold = 100).
  """
  @spec score_metric(map(), number()) :: integer()
  def score_metric(%{good: :high, thresholds: t}, value) do
    value |> score_high_is_good(t) |> clamp(0, 100)
  end

  def score_metric(%{good: _, thresholds: t}, value) do
    value |> score_low_is_good(t) |> clamp(0, 100)
  end

  @doc """
  Maps cosine similarity [-1, +1] to a score [0, 100] with linear interpolation
  within each band. Result is clamped to [0, 100] and rounded to an integer.

  | Cosine range  | Score range |
  |---------------|-------------|
  | [0.5, 1.0]    | [90, 100]   |
  | [0.2, 0.5)    | [70, 90)    |
  | [0.0, 0.2)    | [50, 70)    |
  | [-0.3, 0.0)   | [30, 50)    |
  | [-1.0, -0.3)  | [0, 30)     |
  """
  @spec score_cosine(float()) :: integer()
  def score_cosine(cosine) do
    cosine
    |> cosine_to_score()
    |> clamp(0, 100)
    |> round()
  end

  defp cosine_to_score(c) when c >= 0.5, do: interpolate_between(c, 0.5, 90, 1.0, 100)
  defp cosine_to_score(c) when c >= 0.2, do: interpolate_between(c, 0.2, 70, 0.5, 90)
  defp cosine_to_score(c) when c >= 0.0, do: interpolate_between(c, 0.0, 50, 0.2, 70)
  defp cosine_to_score(c) when c >= -0.3, do: interpolate_between(c, -0.3, 30, 0.0, 50)
  defp cosine_to_score(c), do: interpolate_between(c, -1.0, 0, -0.3, 30)

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
            good: metric_def.good,
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

  @doc """
  Compute overall score as a weighted average of category scores.

  Each category's weight is looked up from `impact_map` by converting
  `category.key` (atom) to string. Defaults to `1` if the key is absent.

  Backward compatible: calling with two arguments (empty `impact_map`) produces
  the same arithmetic mean as the old `/2` signature.
  """
  @spec overall_score(
          categories :: [map()],
          grade_scale :: [{number(), String.t()}],
          impact_map :: %{String.t() => pos_integer()}
        ) :: {integer(), String.t()}
  def overall_score(
        category_grades,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale(),
        impact_map \\ %{}
      ) do
    if category_grades == [] do
      {0, "F"}
    else
      {weighted_sum, total_impact} =
        Enum.reduce(category_grades, {0, 0}, fn g, {ws, ti} ->
          impact = Map.get(impact_map, to_string(g.key), 1)
          {ws + g.score * impact, ti + impact}
        end)

      avg = round(weighted_sum / total_impact)
      {avg, grade_letter(avg, scale)}
    end
  end

  @doc """
  Grade codebase aggregate metrics using cosine similarity.

  Calls `SampleRunner.diagnose_aggregate/2` to get all behaviors with cosine
  values, groups them by category, and returns a graded category list suitable
  for use with `overall_score/3`.

  Categories with zero behaviors are skipped.
  """
  @spec grade_cosine_categories(
          aggregate :: map(),
          worst_files :: %{String.t() => [map()]},
          grade_scale :: [{number(), String.t()}],
          languages :: [String.t()]
        ) :: [map()]
  def grade_cosine_categories(
        aggregate,
        worst_files,
        scale \\ CodeQA.HealthReport.Categories.default_grade_scale(),
        languages \\ []
      ) do
    threshold = CodeQA.Config.cosine_significance_threshold()

    aggregate
    |> SampleRunner.diagnose_aggregate(top: 99_999, languages: languages)
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, behaviors} ->
      behavior_entries =
        behaviors
        |> Enum.reject(fn b -> abs(b.cosine) < threshold end)
        |> Enum.map(fn b ->
          cosine_score = score_cosine(b.cosine)

          %{
            behavior: b.behavior,
            cosine: b.cosine,
            score: cosine_score,
            grade: grade_letter(cosine_score, scale),
            worst_offenders: Map.get(worst_files, "#{category}.#{b.behavior}", [])
          }
        end)

      category_score =
        if behavior_entries == [] do
          50
        else
          round(Enum.sum(Enum.map(behavior_entries, & &1.score)) / length(behavior_entries))
        end

      %{
        type: :cosine,
        key: category,
        name: humanize_category(category),
        score: category_score,
        grade: grade_letter(category_score, scale),
        behaviors: behavior_entries
      }
    end)
  end

  defp humanize_category(slug) do
    slug
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
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
    # TODO(option-c): threshold metric scores are file-level aggregates; line-level attribution would require each AST node to carry its own per-metric values so that the node with the highest contribution to the bad metric score could be identified and reported directly.
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
        bytes: file_data["bytes"],
        top_nodes: top_3_nodes(Map.get(file_data, "nodes"))
      }
    end)
    |> Enum.filter(fn f -> f.metric_scores != [] end)
    |> Enum.sort_by(& &1.score, :asc)
    |> Enum.take(top_n)
  end

  @doc """
  Returns the top 3 nodes by refactoring potential impact, ranked by cosine_delta sum.

  Only considers top-level nodes; children are not traversed. Returns an empty list
  if input is nil, empty, or nodes lack refactoring_potentials data.
  """
  @spec top_3_nodes(list() | nil) :: list()
  def top_3_nodes(nil), do: []
  def top_3_nodes([]), do: []

  def top_3_nodes(nodes) when is_list(nodes) do
    nodes
    |> Enum.sort_by(&node_impact_score/1, :desc)
    |> Enum.take(3)
  end

  defp node_impact_score(%{"refactoring_potentials" => potentials})
       when is_list(potentials) and potentials != [] do
    Enum.sum(Enum.map(potentials, & &1["cosine_delta"]))
  end

  defp node_impact_score(_), do: 0.0
end
