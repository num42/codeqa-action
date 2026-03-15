defmodule CodeQA.Metrics.CasingEntropy do
  @moduledoc """
  Measures Shannon entropy of identifier casing styles in a file.

  Classifies each identifier as pascal_case, camelCase, snake_case, MACRO_CASE,
  kebab-case, or other, then computes the entropy of that distribution. High
  entropy indicates mixed conventions; low entropy indicates consistent naming.

  ## Output keys

  - `"entropy"` — Shannon entropy of the casing distribution (0.0 = uniform style)
  - `"pascal_case_count"`, `"camel_case_count"`, `"snake_case_count"`,
    `"macro_case_count"`, `"kebab_case_count"`, `"other_count"` — per-style
    counts (only keys for styles that appear are included)

  See [Shannon entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory))
  and [naming conventions](https://en.wikipedia.org/wiki/Naming_convention_(programming)).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "casing_entropy"

  @impl true
  def keys, do: ["entropy", "pascal_case_count", "camel_case_count", "snake_case_count", "macro_case_count", "kebab_case_count", "other_count"]


  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{identifiers: identifiers}) when tuple_size(identifiers) == 0 do
    %{"entropy" => 0.0}
  end

  def analyze(%{identifiers: identifiers}) do
    identifiers_list = Tuple.to_list(identifiers)

    counts =
      identifiers_list
      |> Enum.map(&CodeQA.Metrics.Inflector.detect_casing/1)
      |> Enum.frequencies()

    total = length(identifiers_list)

    entropy =
      counts
      |> Map.values()
      |> Enum.reduce(0.0, fn count, acc ->
        p = count / total
        acc - p * :math.log2(p)
      end)

    %{"entropy" => Float.round(entropy, 4)}
    |> Map.merge(counts_to_output(counts))
  end

  defp counts_to_output(counts) do
    Map.new(counts, fn {k, v} -> {"#{k}_count", v} end)
  end
end
