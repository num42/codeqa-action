defmodule CodeQA.Metrics.NearDuplicateBlocks do
  @moduledoc """
  Core logic for near-duplicate block detection.

  Extracts token blocks from a normalized token stream, filters candidates
  using a bigram shingle index, and computes token-level Levenshtein distance.

  See [edit distance](https://en.wikipedia.org/wiki/Edit_distance).
  """

  @block_sizes [8, 16, 32, 64, 128, 256]
  @max_distance 8

  @doc "Standard Levenshtein distance between two token lists."
  @spec token_edit_distance([String.t()], [String.t()]) :: non_neg_integer()
  def token_edit_distance([], b), do: length(b)
  def token_edit_distance(a, []), do: length(a)

  def token_edit_distance(a, b) do
    a_arr = List.to_tuple(a)
    b_arr = List.to_tuple(b)
    lb = tuple_size(b_arr)
    init_row = List.to_tuple(Enum.to_list(0..lb))
    result_row = levenshtein_rows(a_arr, b_arr, tuple_size(a_arr), lb, init_row, 1)
    elem(result_row, lb)
  end

  defp levenshtein_rows(_a, _b, la, _lb, prev, i) when i > la, do: prev

  defp levenshtein_rows(a, b, la, lb, prev, i) do
    ai = elem(a, i - 1)
    curr = levenshtein_cols(b, lb, prev, i, ai, {i})
    levenshtein_rows(a, b, la, lb, curr, i + 1)
  end

  defp levenshtein_cols(_b, lb, _prev, _i, _ai, curr) when tuple_size(curr) > lb, do: curr

  defp levenshtein_cols(b, lb, prev, i, ai, curr) do
    j = tuple_size(curr)
    cost = if ai == elem(b, j - 1), do: 0, else: 1
    val = min(elem(prev, j) + 1, min(elem(curr, j - 1) + 1, elem(prev, j - 1) + cost))
    levenshtein_cols(b, lb, prev, i, ai, Tuple.insert_at(curr, tuple_size(curr), val))
  end
end
