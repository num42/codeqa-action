defmodule CodeQA.HealthReport.Formatter.Shared do
  @moduledoc "Shared formatter helpers used by both Github and Plain renderers."

  @doc """
  PR-summary table row, shared by both formatters.

  Returns an empty list when called with `nil` so callers can splice the
  result into a flat list without branching.
  """
  @spec pr_summary_section(map() | nil) :: [String.t()]
  def pr_summary_section(nil), do: []

  def pr_summary_section(summary) do
    delta_str =
      if summary.score_delta >= 0,
        do: "+#{summary.score_delta}",
        else: "#{summary.score_delta}"

    status_str = "#{summary.files_modified} modified, #{summary.files_added} added"

    [
      "> **Score:** #{summary.base_grade} → #{summary.head_grade}  |  **Δ** #{delta_str} pts  |  **#{summary.blocks_flagged}** blocks flagged across #{summary.files_changed} files  |  #{status_str}",
      ""
    ]
  end
end
