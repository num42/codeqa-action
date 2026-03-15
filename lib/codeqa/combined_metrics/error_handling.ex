defmodule CodeQA.CombinedMetrics.ErrorHandling do
  @moduledoc """
  Behaviour and submodule registry for error handling quality metrics.

  Scalar weights are defined in `priv/combined_metrics/error_handling.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/error_handling.yml"

  @behaviors [
    {"does_not_swallow_errors",
     "Errors must be handled or re-raised — empty rescue/catch blocks silently hide failures."},
    {"error_message_is_descriptive",
     "Error values should carry a meaningful message, not just a bare atom or empty string."},
    {"returns_typed_error",
     "Functions should signal failure via a typed return (e.g. `{:error, reason}`) rather than returning `nil` or `false`."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.ErrorHandling, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.ErrorHandling
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.ErrorHandling.compute_score(@score_key, metrics)
    end
  end
end
