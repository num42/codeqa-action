defmodule CodeQA.Metrics.File.MTLD do
  @moduledoc """
  Measure of Textual Lexical Diversity (MTLD) over the identifier sequence.

  Where `Metrics.File.Vocabulary` reports TTR and window-based MATTR, MTLD
  factors the sequence into segments: a factor completes each time the running
  TTR of the current segment drops to or below the threshold (0.72). The
  remainder contributes a partial factor of `(1 - ttr) / (1 - threshold)`.
  MTLD is the token count divided by the factor count, averaged over a forward
  and a backward pass (standard bidirectional MTLD).

  A sequence whose TTR never reaches the threshold (e.g. all-unique
  identifiers) completes no factor and has a zero partial factor; MTLD is then
  the sequence length — the maximal observable factor length.

  See McCarthy & Jarvis (2010), [MTLD](https://doi.org/10.3758/BRM.42.2.381).
  """

  alias CodeQA.Engine.FileContext

  @behaviour CodeQA.Metrics.File.FileMetric

  @threshold 0.72

  @impl true
  def name, do: "mtld"

  @impl true
  def keys, do: ["mtld", "mtld_forward", "mtld_backward"]

  @impl true
  def description,
    do: "Lexical diversity via TTR-threshold sequence factorization (MTLD)."

  @spec analyze(FileContext.t()) :: map()
  @impl true
  def analyze(%FileContext{identifiers: []}) do
    %{"mtld" => 0.0, "mtld_forward" => 0.0, "mtld_backward" => 0.0}
  end

  def analyze(%FileContext{identifiers: identifiers}) do
    forward = mtld_pass(identifiers)
    backward = identifiers |> Enum.reverse() |> mtld_pass()

    %{
      "mtld" => Float.round((forward + backward) / 2, 4),
      "mtld_forward" => Float.round(forward, 4),
      "mtld_backward" => Float.round(backward, 4)
    }
  end

  defp mtld_pass(identifiers) do
    total = length(identifiers)
    factors = count_factors(identifiers, MapSet.new(), 0, 0.0)

    if factors == 0.0, do: total * 1.0, else: total / factors
  end

  defp count_factors([], _types, 0, factors), do: factors

  defp count_factors([], types, seg_tokens, factors) do
    ttr = MapSet.size(types) / seg_tokens
    factors + (1 - ttr) / (1 - @threshold)
  end

  defp count_factors([id | rest], types, seg_tokens, factors) do
    types = MapSet.put(types, id)
    seg_tokens = seg_tokens + 1

    if MapSet.size(types) / seg_tokens <= @threshold do
      count_factors(rest, MapSet.new(), 0, factors + 1.0)
    else
      count_factors(rest, types, seg_tokens, factors)
    end
  end
end
