defmodule CodeQA.CombinedMetrics.TypeAndValue do
  @moduledoc """
  Behaviour and submodule registry for type safety and value assignment quality metrics.

  Scalar weights are defined in `priv/combined_metrics/type_and_value.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  @yaml_path "priv/combined_metrics/type_and_value.yml"

  use CodeQA.CombinedMetrics.Category, yaml_path: @yaml_path

  @behaviors @yaml_path
             |> YamlElixir.read_from_file!()
             |> Enum.filter(fn {_k, v} -> is_map(v) end)
             |> Enum.map(fn {key, groups} -> {key, Map.get(groups, "_doc")} end)

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.TypeAndValue, Macro.camelize(key)) do
      alias CodeQA.CombinedMetrics.TypeAndValue
      @moduledoc doc
      @behaviour TypeAndValue
      @score_key key
      @impl true
      def score(metrics),
        do: TypeAndValue.compute_score(@score_key, metrics)
    end
  end
end
