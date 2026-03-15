defmodule CodeQA.CombinedMetrics.ScopeAndAssignment do
  @moduledoc """
  Behaviour and submodule registry for variable scope and assignment quality metrics.

  Scalar weights are defined in `priv/combined_metrics/scope_and_assignment.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/scope_and_assignment.yml"

  @behaviors [
    {"declared_close_to_use",
     "Variables should be declared near their first use, not hoisted to the top of the function."},
    {"mutated_after_initial_assignment",
     "Variables should not be reassigned after their initial value — prefer introducing a new name."},
    {"reassigned_multiple_times",
     "A variable reassigned many times is a sign the name is too generic or the function does too much."},
    {"scope_is_minimal",
     "Variables should be scoped as narrowly as possible — not declared at a wider scope than needed."},
    {"shadowed_by_inner_scope",
     "Inner-scope names that shadow outer-scope names cause confusion about which value is in play."},
    {"used_only_once",
     "A variable used only once is a candidate for inlining — it rarely adds clarity over a direct expression."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.ScopeAndAssignment, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.ScopeAndAssignment
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.ScopeAndAssignment.compute_score(@score_key, metrics)
    end
  end
end
