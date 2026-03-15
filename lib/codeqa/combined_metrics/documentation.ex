defmodule CodeQA.CombinedMetrics.Documentation do
  @moduledoc """
  Behaviour and submodule registry for documentation quality metrics.

  Scalar weights are defined in `priv/combined_metrics/documentation.yml`.
  See `CodeQA.CombinedMetrics.Category` for the scoring model.
  """

  use CodeQA.CombinedMetrics.Category,
    yaml_path: "priv/combined_metrics/documentation.yml"

  @behaviors [
    {"docstring_is_nonempty",
     "Docstrings must contain meaningful content, not just a placeholder or empty string."},
    {"file_has_license_header",
     "Source files should begin with a license or copyright header."},
    {"file_has_module_docstring",
     "Files should have a module-level docstring explaining purpose and usage."},
    {"file_has_no_commented_out_code",
     "Files should not contain commented-out code blocks left from development."},
    {"function_has_docstring",
     "Public functions should have a docstring describing behaviour, params, and return value."},
    {"function_todo_comment_in_body",
     "Functions should not contain TODO/FIXME comments indicating unfinished work."}
  ]

  for {key, doc} <- @behaviors do
    defmodule Module.concat(CodeQA.CombinedMetrics.Documentation, Macro.camelize(key)) do
      @moduledoc doc
      @behaviour CodeQA.CombinedMetrics.Documentation
      @score_key key
      @impl true
      def score(metrics),
        do: CodeQA.CombinedMetrics.Documentation.compute_score(@score_key, metrics)
    end
  end
end
