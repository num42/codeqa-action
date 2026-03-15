defmodule CodeQA.CombinedMetrics.VariableNaming do
  @moduledoc """
  Behaviour and submodule registry for variable naming quality metrics.

  Scalar weights are defined in `priv/combined_metrics/variable_naming.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/variable_naming.yml"

  @behaviors [
    {"boolean_has_is_has_prefix",
     "Boolean variables should be prefixed with `is_`, `has_`, or `can_`."},
    {"collection_name_is_plural",
     "Variables holding a collection should use a plural name."},
    {"loop_var_is_single_letter",
     "Loop index variables (`i`, `j`, `k`) are acceptable inside loop bodies."},
    {"name_contains_and",
     "Variable names containing `and` signal a variable that holds two concerns."},
    {"name_contains_type_suffix",
     "Type suffixes in names (`userString`, `nameList`) are redundant noise."},
    {"name_is_abbreviation",
     "Abbreviated names (`usr`, `cfg`, `mgr`) reduce readability."},
    {"name_is_generic",
     "Generic names (`data`, `result`, `tmp`, `val`, `obj`) convey no domain meaning."},
    {"name_is_number_like",
     "Number-suffixed names (`var1`, `thing2`) signal a missing abstraction."},
    {"name_is_single_letter",
     "Single-letter names outside loop indices are too opaque."},
    {"name_is_too_long",
     "Names longer than ~30 characters harm readability."},
    {"name_is_too_short",
     "Names shorter than 3 characters (outside loops) are too opaque."},
    {"negated_boolean_name",
     "Negated boolean names (`isNotValid`, `notActive`) are harder to reason about."},
    {"no_hungarian_notation",
     "Hungarian notation prefixes (`strName`, `bFlag`) add noise without type safety."},
    {"screaming_snake_for_constants",
     "Module-level constants should use SCREAMING_SNAKE_CASE."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.VariableNaming, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.VariableNaming
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.VariableNaming.compute_score(@score_key, metrics)
    end
  end
end
