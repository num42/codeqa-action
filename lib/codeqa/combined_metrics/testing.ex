defmodule CodeQA.CombinedMetrics.Testing do
  @moduledoc """
  Behaviour and submodule registry for test quality metrics.

  Scalar weights are defined in `priv/combined_metrics/testing.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/testing.yml"

  @behaviors [
    {"reasonable_test_to_code_ratio",
     "There should be an adequate number of test cases relative to the code being tested."},
    {"test_has_assertion",
     "Every test body must contain at least one assertion — a test without assertions proves nothing."},
    {"test_name_describes_behavior",
     "Test names should describe the expected behaviour, not just the method under test."},
    {"test_single_concept",
     "Each test should verify a single concept — tests covering multiple things are harder to diagnose when they fail."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.Testing, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.Testing
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.Testing.compute_score(@score_key, metrics)
    end
  end
end
