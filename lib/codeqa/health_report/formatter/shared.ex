defmodule CodeQA.HealthReport.Formatter.Shared do
  @moduledoc """
  Shared formatter helpers.

  Extracted by `mix refactor --only ExtractParametricClone`. Both
  `Formatter.Github` and `Formatter.Plain` carried identical
  `count_severities/1` and `worst_severity/1` implementations.
  """

  @spec worst_severity_shared(map()) :: :critical | :high | :medium | :none
  def worst_severity_shared(counts) do
    cond do
      Map.get(counts, :critical, 0) > 0 -> :critical
      Map.get(counts, :high, 0) > 0 -> :high
      Map.get(counts, :medium, 0) > 0 -> :medium
      true -> :none
    end
  end

  @spec count_severities_shared([map()]) :: %{atom() => non_neg_integer()}
  def count_severities_shared(blocks),
    do:
      blocks
      |> Enum.map(&(List.first(&1.potentials) || %{severity: :medium}).severity)
      |> Enum.frequencies()

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
