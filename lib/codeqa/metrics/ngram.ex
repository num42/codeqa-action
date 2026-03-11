defmodule CodeQA.Metrics.Ngram do
  @moduledoc false

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "ngram"

  @impl true
  def analyze(ctx) do
    tokens = Tuple.to_list(ctx.tokens)

    bigram_stats = ngram_stats(tokens, 2) |> rename_keys("bigram")
    trigram_stats = ngram_stats(tokens, 3) |> rename_keys("trigram")

    Map.merge(bigram_stats, trigram_stats)
  end

  defp ngram_stats(tokens, n) when length(tokens) < n do
    %{"total" => 0, "unique" => 0, "repetition_rate" => 0.0, "hapax_fraction" => 0.0}
  end

  defp ngram_stats(tokens, n) do
    grams = tokens |> Enum.chunk_every(n, 1, :discard)
    counts = Enum.frequencies(grams)
    total = length(grams)
    unique = map_size(counts)
    repeated = counts |> Map.values() |> Enum.filter(&(&1 > 1)) |> Enum.sum()
    hapax = counts |> Map.values() |> Enum.count(&(&1 == 1))

    %{
      "total" => total,
      "unique" => unique,
      "repetition_rate" => repeated / max(total, 1),
      "hapax_fraction" => if(unique > 0, do: hapax / unique, else: 0.0)
    }
  end

  defp rename_keys(map, prefix) do
    Map.new(map, fn {k, v} -> {"#{prefix}_#{k}", v} end)
  end
end
