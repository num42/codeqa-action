defmodule CodeQA.CombinedMetrics.FunctionDesign do
  @moduledoc """
  Behaviour and submodule registry for function design quality metrics.

  Scalar weights are defined in `priv/combined_metrics/function_design.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/function_design.yml"

  @behaviors [
    {"boolean_function_has_question_mark",
     "Functions returning a boolean should end with `?` (Elixir/Ruby) or start with `is_`/`has_` (JS/Python)."},
    {"cyclomatic_complexity_under_10",
     "Functions should have a cyclomatic complexity under 10."},
    {"has_verb_in_name",
     "Function names should contain a verb describing the action performed."},
    {"is_less_than_20_lines",
     "Functions should be 20 lines or fewer."},
    {"nesting_depth_under_4",
     "Code should not nest deeper than 4 levels."},
    {"no_boolean_parameter",
     "Functions should not take boolean parameters — a flag usually means the function does two things."},
    {"no_magic_numbers",
     "Numeric literals should be named constants, not inline magic numbers."},
    {"parameter_count_under_4",
     "Functions should take fewer than 4 parameters."},
    {"uses_ternary_expression",
     "Simple conditional assignments should use inline expressions rather than full if-blocks."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.FunctionDesign, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.FunctionDesign
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.FunctionDesign.compute_score(@score_key, metrics)
    end
  end
end
