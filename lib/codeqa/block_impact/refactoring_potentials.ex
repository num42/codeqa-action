defmodule CodeQA.BlockImpact.RefactoringPotentials do
  @moduledoc """
  Computes named refactoring potentials for a code block using leave-one-out cosine deltas.

  Given baseline and without-node metrics at both file scope and codebase scope,
  computes the cosine delta per behavior, merges the two scopes via max(), and
  returns the top N behaviors sorted by delta descending.

  Positive delta = removing the block improved that behavior's cosine → the block
  is a contributor to that anti-pattern.
  """

  alias CodeQA.CombinedMetrics.FileScorer
  alias CodeQA.CombinedMetrics.SampleRunner

  @doc """
  Returns top N refactoring potentials for a code block.

  ## Parameters

  - `baseline_file_cosines` — pre-computed cosines list from `SampleRunner.diagnose_aggregate/2` for the baseline file
  - `without_file_metrics` — raw `%{"group" => %{"key" => val}}` with the node's tokens removed
  - `baseline_codebase_cosines` — pre-computed cosines list for the full codebase baseline
  - `without_codebase_agg` — `%{"group" => %{"mean_key" => val}}` with the node removed from the codebase

  ## Options

  - `:top` — number of potentials to return (default 3)

  ## Result shape

      [%{"category" => "function_design", "behavior" => "cyclomatic_complexity_under_10", "cosine_delta" => 0.41}]
  """
  @spec compute([map()], map(), [map()], map(), keyword()) :: [map()]
  def compute(
        baseline_file_cosines,
        without_file_metrics,
        baseline_codebase_cosines,
        without_codebase_agg,
        opts \\ []
      ) do
    top_n = Keyword.get(opts, :top, 3)

    file_delta = compute_file_delta(baseline_file_cosines, without_file_metrics)
    codebase_delta = compute_codebase_delta(baseline_codebase_cosines, without_codebase_agg)

    all_keys = Enum.uniq(Map.keys(file_delta) ++ Map.keys(codebase_delta))

    all_keys
    |> Enum.map(fn {category, behavior} ->
      file_d = Map.get(file_delta, {category, behavior}, 0.0)
      codebase_d = Map.get(codebase_delta, {category, behavior}, 0.0)
      merged = max(file_d, codebase_d)
      {category, behavior, merged}
    end)
    |> Enum.sort_by(fn {_, _, delta} -> delta end, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {category, behavior, delta} ->
      %{
        "category" => category,
        "behavior" => behavior,
        "cosine_delta" => Float.round(delta / 1.0, 4)
      }
    end)
  end

  defp compute_file_delta(baseline_cosines, without_metrics) do
    without_agg = FileScorer.file_to_aggregate(without_metrics)
    without_cosines = SampleRunner.diagnose_aggregate(without_agg, top: 99_999)
    cosines_to_delta(baseline_cosines, without_cosines)
  end

  defp compute_codebase_delta(baseline_cosines, without_agg) do
    without_cosines = SampleRunner.diagnose_aggregate(without_agg, top: 99_999)
    cosines_to_delta(baseline_cosines, without_cosines)
  end

  defp cosines_to_delta(baseline_cosines, without_cosines) do
    without_map =
      Map.new(without_cosines, fn %{category: c, behavior: b, cosine: cos} -> {{c, b}, cos} end)

    Map.new(baseline_cosines, fn %{category: c, behavior: b, cosine: cos} ->
      without_cos = Map.get(without_map, {c, b}, 0.0)
      {{c, b}, without_cos - cos}
    end)
  end
end
