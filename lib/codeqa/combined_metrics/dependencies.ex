defmodule CodeQA.CombinedMetrics.Dependencies do
  @moduledoc """
  Behaviour and submodule registry for dependency and coupling quality metrics.

  Scalar weights are defined in `priv/combined_metrics/dependencies.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  @yaml_path "priv/combined_metrics/dependencies.yml"

  use CodeQA.CombinedMetrics.Category, yaml_path: @yaml_path

  @behaviors @yaml_path
             |> YamlElixir.read_from_file!()
             |> Enum.filter(fn {_k, v} -> is_map(v) end)
             |> Enum.map(fn {key, groups} -> {key, Map.get(groups, "_doc")} end)

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.Dependencies, Macro.camelize(key)) do
      alias CodeQA.CombinedMetrics.Dependencies
      @moduledoc doc
      @behaviour Dependencies
      @score_key key
      @impl true
      def score(metrics),
        do: Dependencies.compute_score(@score_key, metrics)
    end
  end
end
