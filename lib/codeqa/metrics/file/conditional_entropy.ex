defmodule CodeQA.Metrics.File.ConditionalEntropy do
  @moduledoc """
  Measures how predictable each token is from its predecessor.

  Where `Metrics.File.Entropy` reports order-0 Shannon entropy (token
  frequency only) and `Metrics.File.Ngram` counts bigrams without modelling
  transitions, this metric computes the conditional entropy of the token
  sequence:

      H(tₙ | tₙ₋₁) = Σ P(prev) · H(next | prev)

  Low conditional entropy means formulaic, highly predictable token chains
  (`with {:ok, _} <- …`); high means dense, unpredictable one-liners.
  Perplexity `PP = 2^H` reads as a linear branching factor.

  See [conditional entropy](https://en.wikipedia.org/wiki/Conditional_entropy)
  and [perplexity](https://en.wikipedia.org/wiki/Perplexity).
  """

  alias CodeQA.Engine.FileContext

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "conditional_entropy"

  @impl true
  def keys, do: ["conditional_entropy", "perplexity", "normalized_conditional_entropy"]

  @impl true
  def description,
    do: "Conditional entropy H(tₙ|tₙ₋₁) and Markov perplexity of the token sequence."

  @spec analyze(FileContext.t()) :: map()
  @impl true
  def analyze(%FileContext{tokens: tokens}) when length(tokens) < 2 do
    zero_result()
  end

  def analyze(%FileContext{tokens: tokens}) do
    bigrams = tokens |> Enum.map(& &1.content) |> Enum.chunk_every(2, 1, :discard)
    total = length(bigrams)

    by_prev = Enum.group_by(bigrams, &hd/1, &List.last/1)
    entropy = conditional_entropy(by_prev, total)
    max_entropy = max_entropy(by_prev)

    %{
      "conditional_entropy" => Float.round(entropy, 4),
      "perplexity" => Float.round(:math.pow(2, entropy), 4),
      "normalized_conditional_entropy" =>
        if(max_entropy > 0, do: Float.round(entropy / max_entropy, 4), else: 0.0)
    }
  end

  # Weighted sum of per-predecessor successor entropies, weighted by P(prev).
  defp conditional_entropy(by_prev, total) do
    Enum.reduce(by_prev, 0.0, fn {_prev, successors}, acc ->
      prev_weight = length(successors) / total
      acc + prev_weight * successor_entropy(successors)
    end)
  end

  defp successor_entropy(successors) do
    n = length(successors)

    successors
    |> Enum.frequencies()
    |> Enum.reduce(0.0, fn {_next, count}, acc ->
      p = count / n
      acc - p * :math.log2(p)
    end)
  end

  # Theoretical maximum: uniform over the distinct successors observed.
  defp max_entropy(by_prev) do
    distinct_successors = by_prev |> Map.values() |> List.flatten() |> Enum.uniq() |> length()
    if distinct_successors > 1, do: :math.log2(distinct_successors), else: 0.0
  end

  defp zero_result do
    %{
      "conditional_entropy" => 0.0,
      "perplexity" => 1.0,
      "normalized_conditional_entropy" => 0.0
    }
  end
end
