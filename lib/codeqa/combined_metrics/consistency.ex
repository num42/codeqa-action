defmodule CodeQA.CombinedMetrics.Consistency do
  @moduledoc """
  Behaviour and submodule registry for codebase consistency metrics.

  Covers naming style uniformity, structural patterns, and cross-file coherence.
  Scalar weights are defined in `priv/combined_metrics/consistency.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  @yaml_path "priv/combined_metrics/consistency.yml"

  use CodeQA.CombinedMetrics.Category, yaml_path: @yaml_path

  @behaviors @yaml_path
             |> YamlElixir.read_from_file!()
             |> Enum.filter(fn {_k, v} -> is_map(v) end)
             |> Enum.map(fn {key, groups} -> {key, Map.get(groups, "_doc")} end)

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.Consistency, Macro.camelize(key)) do
      alias CodeQA.CombinedMetrics.Consistency
      @moduledoc doc
      @behaviour Consistency
      @score_key key
      @impl true
      def score(metrics),
        do: Consistency.compute_score(@score_key, metrics)
    end
  end
end
