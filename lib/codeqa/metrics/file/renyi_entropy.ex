defmodule CodeQA.Metrics.File.RenyiEntropy do
  @moduledoc """
  Computes the Rényi entropy spectrum and Hill numbers over the token
  distribution.

  Rényi entropy `H_α` generalizes Shannon entropy across an order parameter
  `α`: low orders weight rare tokens, high orders only the dominant ones. The
  spectrum `H₀ ≥ H₁ ≥ H₂ ≥ H_∞` therefore characterizes the *shape* of the
  distribution rather than a single scalar. `spectrum_slope = H₀ − H₂` is a
  concentration indicator: near zero for a flat (uniform) vocabulary, large
  when a few tokens dominate.

  Hill numbers `D_α = 2^(H_α)` express the *effective vocabulary size* — how
  many tokens really count — which is more interpretable than raw `vocab_size`.

  See [Rényi entropy](https://en.wikipedia.org/wiki/R%C3%A9nyi_entropy) and
  [Hill numbers / diversity](https://en.wikipedia.org/wiki/Diversity_index#Effective_number_of_species).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "renyi_entropy"

  @impl true
  def keys,
    do: [
      "renyi_0",
      "renyi_1",
      "renyi_2",
      "renyi_inf",
      "hill_1",
      "hill_2",
      "spectrum_slope"
    ]

  @impl true
  def description,
    do:
      "Rényi entropy spectrum (α ∈ {0,1,2,∞}) and Hill numbers (effective vocabulary size) over the token distribution."

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{tokens: []}), do: zero_result()

  def analyze(%{token_counts: token_counts, tokens: tokens}) do
    total = length(tokens)
    probs = token_counts |> Map.values() |> Enum.map(&(&1 / total))
    spectrum(probs)
  end

  defp spectrum(probs) do
    h0 = renyi_0(probs)
    h1 = renyi_1(probs)
    h2 = renyi_2(probs)
    h_inf = renyi_inf(probs)

    %{
      "renyi_0" => round4(h0),
      "renyi_1" => round4(h1),
      "renyi_2" => round4(h2),
      "renyi_inf" => round4(h_inf),
      "hill_1" => round4(hill(h1)),
      "hill_2" => round4(hill(h2)),
      "spectrum_slope" => round4(h0 - h2)
    }
  end

  # H₀ = log2(support size) — Hartley entropy, counts only distinct tokens.
  defp renyi_0(probs), do: log2(length(probs))

  # H₁ = -Σ pᵢ log2 pᵢ — Shannon entropy, the α→1 limit.
  defp renyi_1(probs),
    do: -Enum.reduce(probs, 0.0, fn p, acc -> acc + p * :math.log2(p) end)

  # H₂ = -log2(Σ pᵢ²) — collision entropy.
  defp renyi_2(probs) do
    sum_sq = Enum.reduce(probs, 0.0, fn p, acc -> acc + p * p end)
    -:math.log2(sum_sq)
  end

  # H_∞ = -log2(max pᵢ) — min-entropy, governed by the most frequent token.
  defp renyi_inf(probs), do: -:math.log2(Enum.max(probs))

  # Hill number D_α = 2^(H_α), the effective vocabulary size.
  defp hill(h), do: :math.pow(2, h)

  defp log2(n) when n > 0, do: :math.log2(n)
  defp log2(_), do: 0.0

  defp round4(x), do: Float.round(x * 1.0, 4)

  defp zero_result,
    do: %{
      "renyi_0" => 0.0,
      "renyi_1" => 0.0,
      "renyi_2" => 0.0,
      "renyi_inf" => 0.0,
      "hill_1" => 0.0,
      "hill_2" => 0.0,
      "spectrum_slope" => 0.0
    }
end
