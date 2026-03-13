defmodule CodeQA.Metrics.Entropy do
  @moduledoc """
  Computes Shannon entropy at both character and token levels.

  Character entropy captures the randomness of the raw byte stream, while token
  entropy measures the predictability of the lexical token sequence. Both values
  are also reported as normalized (0..1) against their theoretical maxima.

  See [Shannon entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory)).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "entropy"

  @impl true
  def analyze(ctx) do
    Map.merge(char_entropy(ctx.content), token_entropy(ctx))
  end

  defp char_entropy(""),
    do: %{"char_entropy" => 0.0, "char_max_entropy" => 0.0, "char_normalized" => 0.0}

  defp char_entropy(content) do
    counts = content |> String.graphemes() |> Enum.frequencies()
    total = String.length(content)
    compute_entropy(counts, total, "char")
  end

  defp token_entropy(%{tokens: tokens, token_counts: _token_counts})
       when tuple_size(tokens) == 0 do
    %{
      "token_entropy" => 0.0,
      "token_max_entropy" => 0.0,
      "token_normalized" => 0.0,
      "vocab_size" => 0,
      "total_tokens" => 0
    }
  end

  defp token_entropy(%{tokens: tokens, token_counts: token_counts}) do
    total = tuple_size(tokens)
    vocab_size = map_size(token_counts)

    entropy_map = compute_entropy(token_counts, total, "token")
    Map.merge(entropy_map, %{"vocab_size" => vocab_size, "total_tokens" => total})
  end

  defp compute_entropy(counts, total, prefix) do
    alphabet_size = map_size(counts)
    max_entropy = if alphabet_size > 1, do: :math.log2(alphabet_size), else: 0.0

    entropy =
      counts
      |> Map.values()
      |> Enum.reduce(0.0, fn c, acc ->
        p = c / total
        acc - p * :math.log2(p)
      end)

    normalized = if max_entropy > 0, do: entropy / max_entropy, else: 0.0

    %{
      "#{prefix}_entropy" => entropy,
      "#{prefix}_max_entropy" => max_entropy,
      "#{prefix}_normalized" => normalized
    }
  end
end
