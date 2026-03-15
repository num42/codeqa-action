defmodule CodeQA.CombinedMetrics.Consistency do
  @moduledoc """
  Behaviour and submodule registry for codebase consistency metrics.

  Covers naming style uniformity, structural patterns, and cross-file coherence.
  Scalar weights are defined in `priv/combined_metrics/consistency.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/consistency.yml"

  @behaviors [
    {"consistent_casing_within_file",
     "A file should use one naming convention throughout — no mixing of camelCase and snake_case for the same kind of identifier."},
    {"consistent_error_return_shape",
     "All functions in a module should return errors in the same shape — mixed `nil`, `false`, and `{:error, _}` returns are confusing."},
    {"consistent_function_style",
     "A module should not mix one-liner and multi-clause function definitions for the same concern."},
    {"same_concept_same_name",
     "The same domain concept should use the same name throughout a file — mixing `user`, `usr`, and `u` for the same thing harms readability."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.Consistency, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.Consistency
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.Consistency.compute_score(@score_key, metrics)
    end
  end
end
