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
  def count_severities_shared(blocks) do
    blocks
    |> Enum.map(&(List.first(&1.potentials) || %{severity: :medium}).severity)
    |> Enum.frequencies()
  end
end
