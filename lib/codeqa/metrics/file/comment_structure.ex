defmodule CodeQA.Metrics.File.CommentStructure do
  @moduledoc """
  Measures comment density and annotation patterns.

  Counts lines that begin with a comment marker (language-agnostic: `#`, `//`,
  `/*`, ` *`) relative to non-blank lines. Also counts TODO/FIXME/HACK/XXX
  markers which indicate deferred work or known issues.

  ## Output keys

  - `"comment_line_ratio"` — comment lines / non-blank lines
  - `"comment_line_count"` — raw count of comment lines
  - `"todo_fixme_count"` — occurrences of TODO, FIXME, HACK, or XXX
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "comment_structure"

  @impl true
  def keys, do: ["comment_line_ratio", "comment_line_count", "todo_fixme_count"]

  @comment_line ~r/^\s*(?:#|\/\/|\/\*|\*)/
  @todo_marker ~r/\b(?:TODO|FIXME|HACK|XXX)\b/

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: content, lines: lines}) do
    non_blank = Enum.reject(lines, &(String.trim(&1) == ""))
    non_blank_count = length(non_blank)

    comment_count = Enum.count(non_blank, &Regex.match?(@comment_line, &1))
    todo_count = @todo_marker |> Regex.scan(content) |> length()

    comment_ratio =
      if non_blank_count > 0, do: Float.round(comment_count / non_blank_count, 4), else: 0.0

    %{
      "comment_line_ratio" => comment_ratio,
      "comment_line_count" => comment_count,
      "todo_fixme_count" => todo_count
    }
  end
end
