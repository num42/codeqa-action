defmodule CodeQA.Metrics.File.Winnowing do
  @moduledoc """
  Generates structural fingerprints using k-grams.

  Slides a window of size `k` over the token list and hashes each sequence.
  Note: this implements k-gram hashing; the full Winnowing algorithm
  additionally applies a sliding-minimum selection over the hash stream.

  See [winnowing algorithm](https://theory.stanford.edu/~aiken/publications/papers/sigmod03.pdf).
  """

  @doc """
  Slides a window of size `k` over the tokens and hashes each sequence.

  If the token list is shorter than `k`, a single hash of the full list is
  returned. This fallback exists so very short files still produce a
  fingerprint, though it is semantically different from a k-gram hash.
  """
  @spec kgrams([String.t()], pos_integer()) :: [integer()]
  def kgrams(tokens, k \\ 5) do
    if length(tokens) < k do
      # Fallback for very short files: hash the whole token list as one fingerprint.
      [hash_sequence(tokens)]
    else
      tokens
      |> Enum.chunk_every(k, 1, :discard)
      |> Enum.map(&hash_sequence/1)
    end
  end

  # Hash the token list directly to preserve token boundaries.
  # Joining to a string first would allow hash collisions across different
  # token sequences that produce the same concatenated string.
  defp hash_sequence(sequence) do
    :erlang.phash2(sequence)
  end
end
