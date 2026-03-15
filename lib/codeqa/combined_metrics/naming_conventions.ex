defmodule CodeQA.CombinedMetrics.NamingConventions do
  @moduledoc """
  Behaviour and submodule registry for broader naming convention metrics.

  Covers class, file, and function naming patterns not captured by
  `VariableNaming`. Scalar weights are defined in
  `priv/combined_metrics/naming_conventions.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/naming_conventions.yml"

  @behaviors [
    {"class_name_is_noun",
     "Class and module names should be nouns describing what they represent, not verbs or gerunds."},
    {"file_name_matches_primary_export",
     "The file name should match the primary class or module it exports (e.g. `user.js` exports `User`)."},
    {"function_name_is_not_single_word",
     "Single-word function names like `run`, `process`, or `handle` are too vague to convey intent."},
    {"function_name_matches_return_type",
     "Functions prefixed with `get_`, `fetch_`, or `find_` should return the thing they name."},
    {"test_name_starts_with_verb",
     "Test descriptions should start with a verb: `creates`, `raises`, `returns`, not a noun phrase."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.NamingConventions, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.NamingConventions
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.NamingConventions.compute_score(@score_key, metrics)
    end
  end
end
