defmodule CodeQA.Metrics.File.SeparatorCounts do
  @moduledoc """
  Counts dividing characters (`_`, `-`, `/`, `.`) in source code.

  These separators appear in identifiers (snake_case, kebab-case),
  paths, and dotted access. Their frequency can distinguish naming
  conventions and structural patterns across languages.
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "separator_counts"

  @impl true
  def keys, do: ["underscore_count", "hyphen_count", "slash_count", "dot_count"]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: content}),
    do: %{
      "underscore_count" => count(content, "_"),
      "hyphen_count" => count(content, "-"),
      "slash_count" => count(content, "/"),
      "dot_count" => count(content, ".")
    }

  @impl true
  def analyze_loo(baseline, block_content),
    do: %{
      "underscore_count" => baseline["underscore_count"] - count(block_content, "_"),
      "hyphen_count" => baseline["hyphen_count"] - count(block_content, "-"),
      "slash_count" => baseline["slash_count"] - count(block_content, "/"),
      "dot_count" => baseline["dot_count"] - count(block_content, ".")
    }

  defp count(content, char),
    do:
      content
      |> String.graphemes()
      |> Enum.count(&(&1 == char))
end
