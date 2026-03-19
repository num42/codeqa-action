defmodule CodeQA.CombinedMetrics.Category do
  @moduledoc """
  Macro helper for defining combined-metric category modules.

  Each category module (e.g. `VariableNaming`, `Documentation`) calls
  `use CodeQA.CombinedMetrics.Category, yaml_path: "priv/..."`.

  This injects:
  - `@callback score(metrics :: map()) :: float()` — making the caller a behaviour
  - `compute_score/2` — delegates to `Scorer` with the baked-in yaml path

  ## Example

      defmodule CodeQA.CombinedMetrics.VariableNaming do
        use CodeQA.CombinedMetrics.Category,
          yaml_path: "priv/combined_metrics/variable_naming.yml"
      end

  Leaf modules then declare `@behaviour CodeQA.CombinedMetrics.VariableNaming`
  and call `VariableNaming.compute_score("key", metrics)`.
  """

  defmacro __using__(yaml_path: yaml_path) do
    quote do
      @callback score(metrics :: map()) :: float()

      @doc """
      Computes the score for `metric_name` using scalars from this category's YAML file.

      Delegates to `CodeQA.CombinedMetrics.Scorer.compute_score/3`.
      """
      @spec compute_score(String.t(), map()) :: float()
      def compute_score(metric_name, metrics) do
        CodeQA.CombinedMetrics.Scorer.compute_score(unquote(yaml_path), metric_name, metrics)
      end
    end
  end
end
