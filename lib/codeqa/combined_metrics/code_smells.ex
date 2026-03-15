defmodule CodeQA.CombinedMetrics.CodeSmells do
  @moduledoc """
  Behaviour and submodule registry for code smell detection metrics.

  Scalar weights are defined in `priv/combined_metrics/code_smells.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/code_smells.yml"

  @behaviors [
    {"consistent_string_quote_style",
     "Files should use a single, consistent string quoting style throughout."},
    {"no_dead_code_after_return",
     "There should be no unreachable statements after a return or early exit."},
    {"no_debug_print_statements",
     "Debug output (`console.log`, `IO.inspect`, `fmt.Println`) must not be left in committed code."},
    {"no_fixme_comments",
     "FIXME, XXX, and HACK comments indicate known problems that should be resolved before merging."},
    {"no_nested_ternary",
     "Nested conditional expressions (ternary-within-ternary) are harder to read than a plain if-else."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.CodeSmells, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.CodeSmells
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.CodeSmells.compute_score(@score_key, metrics)
    end
  end
end
