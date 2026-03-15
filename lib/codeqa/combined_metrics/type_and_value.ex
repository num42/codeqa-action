defmodule CodeQA.CombinedMetrics.TypeAndValue do
  @moduledoc """
  Behaviour and submodule registry for type safety and value assignment quality metrics.

  Scalar weights are defined in `priv/combined_metrics/type_and_value.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/type_and_value.yml"

  @behaviors [
    {"boolean_assigned_from_comparison",
     "Boolean variables should be assigned directly from comparisons or predicate calls, not set via conditionals."},
    {"hardcoded_url_or_path",
     "URLs, file paths, and host names should be configuration values, not inline string literals."},
    {"no_empty_string_initial",
     "Initialising a variable to an empty string and reassigning later signals missing structure."},
    {"no_implicit_null_initial",
     "Initialising a variable to `nil`/`null` and assigning it later in a branch signals missing structure."},
    {"no_magic_value_assigned",
     "Literal strings and numbers assigned to variables should be named constants, not inline values."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.TypeAndValue, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.TypeAndValue
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.TypeAndValue.compute_score(@score_key, metrics)
    end
  end
end
