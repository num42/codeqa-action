defmodule CodeQA.Metrics.File.LexicalConcentration do
  @moduledoc """
  Measures vocabulary concentration via Yule's K and Simpson's D.

  Where the type-token ratio measures lexical *diversity* and drifts with file
  length, these characteristic constants measure *repetition structure* and are
  length-invariant. Both read the frequency spectrum `V_r` — the number of
  tokens occurring exactly `r` times — rather than raw counts.

      K = 10⁴ · (Σ_r r²·V_r − N) / N²    Yule's characteristic constant
      D = Σ_r r·(r−1)·V_r / (N·(N−1))    Simpson's index (repeat probability)

  `K` near 0 means tokens spread evenly; high `K` means a few tokens dominate.
  `D` is the probability that two tokens drawn at random are identical.

  See [Yule's characteristic K](https://en.wikipedia.org/wiki/Mendenhall%27s_law)
  and [Simpson's index](https://en.wikipedia.org/wiki/Diversity_index#Simpson_index).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "lexical_concentration"

  @impl true
  def keys, do: ["yule_k", "simpson_d", "total_tokens"]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{token_counts: token_counts}) do
    frequencies = Map.values(token_counts)
    n = Enum.sum(frequencies)

    if n < 2 do
      %{"yule_k" => 0.0, "simpson_d" => 0.0, "total_tokens" => n}
    else
      spectrum = Enum.frequencies(frequencies)

      %{
        "yule_k" => yule_k(spectrum, n),
        "simpson_d" => simpson_d(spectrum, n),
        "total_tokens" => n
      }
    end
  end

  # K = 10⁴ · (Σ_r r²·V_r − N) / N²
  defp yule_k(spectrum, n) do
    sum_r2_vr = Enum.reduce(spectrum, 0, fn {r, vr}, acc -> acc + r * r * vr end)
    Float.round(10_000 * (sum_r2_vr - n) / (n * n), 4)
  end

  # D = Σ_r r·(r−1)·V_r / (N·(N−1))
  defp simpson_d(spectrum, n) do
    sum = Enum.reduce(spectrum, 0, fn {r, vr}, acc -> acc + r * (r - 1) * vr end)
    Float.round(sum / (n * (n - 1)), 4)
  end
end
