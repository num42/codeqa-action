defmodule CodeQA.CombinedMetrics.Dependencies do
  @moduledoc """
  Behaviour and submodule registry for dependency and coupling quality metrics.

  Scalar weights are defined in `priv/combined_metrics/dependencies.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/dependencies.yml"

  @behaviors [
    {"import_count_under_10",
     "Files should import fewer than 10 modules; high import counts signal excessive coupling."},
    {"low_coupling",
     "Modules should depend on few external symbols — a low unique-operand count relative to total is a proxy for tight coupling."},
    {"no_wildcard_imports",
     "Wildcard imports (`import *`, `using Module`) pollute the local namespace and hide dependencies."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.Dependencies, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.Dependencies
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.Dependencies.compute_score(@score_key, metrics)
    end
  end
end
