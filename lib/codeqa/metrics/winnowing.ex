defmodule CodeQA.Metrics.Winnowing do
  @moduledoc "Generates structural fingerprints using k-grams."

  @doc "Slides a window of size `k` over the tokens and hashes each sequence."
  def kgrams(tokens, k \\ 5) do
    if length(tokens) < k do
      # If chunk is too small, just hash what we have
      [hash_sequence(tokens)]
    else
      tokens
      |> Enum.chunk_every(k, 1, :discard)
      |> Enum.map(&hash_sequence/1)
    end
  end

  defp hash_sequence(sequence) do
    string_rep = Enum.join(sequence, "")
    # Use Erlang's fast phash2 to convert the string to an integer fingerprint
    :erlang.phash2(string_rep)
  end
end