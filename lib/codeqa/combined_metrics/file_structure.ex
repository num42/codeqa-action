defmodule CodeQA.CombinedMetrics.FileStructure do
  @moduledoc """
  Behaviour and submodule registry for file structure quality metrics.

  Scalar weights are defined in `priv/combined_metrics/file_structure.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/file_structure.yml"

  @behaviors [
    {"has_consistent_indentation",
     "Files should use a single, consistent indentation style with no mixed tabs and spaces."},
    {"line_count_under_300",
     "Files should be under 300 lines; longer files typically violate single responsibility."},
    {"line_length_under_120",
     "Lines should be under 120 characters to avoid horizontal scrolling."},
    {"no_magic_numbers",
     "Numeric literals should be extracted to named constants rather than used inline."},
    {"single_responsibility",
     "Each file should have one primary concern — low complexity spread across few, focused functions."},
    {"uses_standard_indentation_width",
     "Indentation should use consistent multiples of 2 or 4 spaces throughout the file."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.FileStructure, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.FileStructure
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.FileStructure.compute_score(@score_key, metrics)
    end
  end
end
