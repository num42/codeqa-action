defmodule CodeQA.CombinedMetrics.CosineVector do
  @moduledoc """
  Computes cosine similarity between a behavior's scalar weight vector and a
  log-metric vector derived from an aggregate.

  Pure math — no I/O, no YAML loading. Intended for internal use by `SampleRunner`.
  """

  alias CodeQA.CombinedMetrics.Scorer

  @doc """
  Builds the cosine result entry for a single behavior against the given aggregate.

  Returns a one-element list `[result_map]` on success or `[]` when the behavior
  has no non-zero scalars (no sample data) and should be excluded.
  """
  @spec compute(String.t(), String.t(), map(), map(), String.t()) :: [map()]
  def compute(yaml_path, behavior, behavior_data, aggregate, category) do
    scalars = Scorer.scalars_for(yaml_path, behavior)

    if map_size(scalars) == 0 do
      []
    else
      build_result(yaml_path, behavior, behavior_data, aggregate, category, scalars)
    end
  end

  # --- Internal helpers ---

  defp build_result(yaml_path, behavior, behavior_data, aggregate, category, scalars) do
    log_baseline = Map.get(behavior_data, "_log_baseline", 0.0) / 1.0

    {dot, norm_s_sq, norm_v_sq, contributions} =
      Enum.reduce(scalars, {0.0, 0.0, 0.0, []}, fn {{group, key}, scalar},
                                                   {d, ns, nv, contribs} ->
        log_m = :math.log(Scorer.get(aggregate, group, key))
        contrib = scalar * log_m

        {d + contrib, ns + scalar * scalar, nv + log_m * log_m,
         [{:"#{group}.#{key}", contrib} | contribs]}
      end)

    cos_sim =
      if norm_s_sq > 0 and norm_v_sq > 0,
        do: dot / (:math.sqrt(norm_s_sq) * :math.sqrt(norm_v_sq)),
        else: 0.0

    raw_score = Scorer.compute_score(yaml_path, behavior, aggregate)
    calibrated = :math.log(max(raw_score, 1.0e-300)) - log_baseline

    top_metrics =
      contributions
      |> Enum.sort_by(fn {_, c} -> c end)
      |> Enum.take(5)
      |> Enum.map(fn {metric, contribution} ->
        %{metric: to_string(metric), contribution: Float.round(contribution, 4)}
      end)

    [
      %{
        category: category,
        behavior: behavior,
        cosine: Float.round(cos_sim, 4),
        score: Float.round(calibrated, 4),
        top_metrics: top_metrics
      }
    ]
  end
end
