defmodule CodeQA.CombinedMetrics.NamingConventions do
  @moduledoc """
  Behaviour and submodule registry for broader naming convention metrics.

  Covers class, file, and function naming patterns not captured by
  `VariableNaming`. Scalar weights are defined in
  `priv/combined_metrics/naming_conventions.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  @yaml_path "priv/combined_metrics/naming_conventions.yml"

  use CodeQA.CombinedMetrics.Category, yaml_path: @yaml_path

  @behaviors @yaml_path
             |> YamlElixir.read_from_file!()
             |> Enum.filter(fn {_k, v} -> is_map(v) end)
             |> Enum.map(fn {key, groups} -> {key, Map.get(groups, "_doc")} end)

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.NamingConventions, Macro.camelize(key)) do
      alias CodeQA.CombinedMetrics.NamingConventions
      @moduledoc doc
      @behaviour NamingConventions
      @score_key key
      @impl true
      def score(metrics),
        do: NamingConventions.compute_score(@score_key, metrics)
    end
  end
end
