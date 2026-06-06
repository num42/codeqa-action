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

  # No `analyze_loo/2`: the subtractive path is incorrect here. The block-impact
  # analyzer subtracts a block whose content is rebuilt from normalized
  # structural tokens (which drop inter-token whitespace), while the baseline is
  # computed from the original file. Counting separators in that whitespace-
  # collapsed block string diverges from re-analyzing the reconstructed file
  # (empirically 0/50 matches). Falling back to a full re-analyze keeps the LOO
  # delta consistent with every other metric.

  defp count(content, char),
    do:
      content
      |> String.graphemes()
      |> Enum.count(&(&1 == char))
end
