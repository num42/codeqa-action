defmodule CodeQA.Metrics.File.NearDuplicateBlocks.Distance do
  @moduledoc """
  Token-level edit distance and percentage-bucket classification for near-duplicate detection.

  Provides standard Levenshtein distance, a bounded variant that short-circuits
  when the distance already exceeds a threshold, and a bucket classifier that maps
  an edit distance + minimum token count to a similarity bucket (d0–d8).

  Distance buckets:
    d0 = exact (0%), d1 ≤ 5%, d2 ≤ 10%, d3 ≤ 15%, d4 ≤ 20%,
    d5 ≤ 25%, d6 ≤ 30%, d7 ≤ 40%, d8 ≤ 50%
  """

  @bucket_thresholds [
    {0, 0.0},
    {1, 0.05},
    {2, 0.10},
    {3, 0.15},
    {4, 0.20},
    {5, 0.25},
    {6, 0.30},
    {7, 0.40},
    {8, 0.50}
  ]

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
    curr_reversed = levenshtein_cols(b, lb, prev, ai, [i], 1)
    curr = List.to_tuple(:lists.reverse(curr_reversed))
    levenshtein_rows(a, b, la, lb, curr, i + 1)
  end

  defp levenshtein_cols(_b, lb, _prev, _ai, acc, j) when j > lb, do: acc

  defp levenshtein_cols(b, lb, prev, ai, [last_val | _] = acc, j) do
    cost = if ai == elem(b, j - 1), do: 0, else: 1
    val = min(elem(prev, j) + 1, min(last_val + 1, elem(prev, j - 1) + cost))
    levenshtein_cols(b, lb, prev, ai, [val | acc], j + 1)
  end

  # Bounded Levenshtein: returns the edit distance, or max_distance + 1 if the
  # distance would exceed max_distance. Bails after each row when the row minimum
  # already exceeds max_distance — the final distance can only grow from there.
  @doc false
  @spec token_edit_distance_bounded([String.t()], [String.t()], non_neg_integer()) ::
          non_neg_integer()
  def token_edit_distance_bounded([], b, _max), do: length(b)
  def token_edit_distance_bounded(a, [], _max), do: length(a)

  def token_edit_distance_bounded(a, b, max_distance) do
    a_arr = List.to_tuple(a)
    b_arr = List.to_tuple(b)
    lb = tuple_size(b_arr)
    init_row = List.to_tuple(Enum.to_list(0..lb))
    levenshtein_rows_bounded(a_arr, b_arr, tuple_size(a_arr), lb, init_row, max_distance, 1)
  end

  defp levenshtein_rows_bounded(_a, _b, la, lb, prev, _max, i) when i > la, do: elem(prev, lb)

  defp levenshtein_rows_bounded(a, b, la, lb, prev, max_distance, i) do
    ai = elem(a, i - 1)
    # levenshtein_cols_with_min tracks the row minimum as it builds, avoiding
    # a separate O(lb) pass to find the min after the row is complete.
    {curr_reversed, row_min} = levenshtein_cols_with_min(b, lb, prev, ai, {[i], i}, 1)
    curr = List.to_tuple(:lists.reverse(curr_reversed))

    if row_min > max_distance do
      max_distance + 1
    else
      levenshtein_rows_bounded(a, b, la, lb, curr, max_distance, i + 1)
    end
  end

  defp levenshtein_cols_with_min(_b, lb, _prev, _ai, acc_and_min, j) when j > lb,
    do: acc_and_min

  defp levenshtein_cols_with_min(b, lb, prev, ai, {[last_val | _] = acc, min_val}, j) do
    cost = if ai == elem(b, j - 1), do: 0, else: 1
    val = min(elem(prev, j) + 1, min(last_val + 1, elem(prev, j - 1) + cost))
    levenshtein_cols_with_min(b, lb, prev, ai, {[val | acc], min(min_val, val)}, j + 1)
  end

  @doc "Map an edit distance and min token count to a percentage bucket 0–8, or nil if > 50%."
  @spec percent_bucket(non_neg_integer(), non_neg_integer()) :: 0..8 | nil
  def percent_bucket(_ed, 0), do: nil
  def percent_bucket(0, _min_count), do: 0

  def percent_bucket(ed, min_count) do
    pct = ed / min_count

    @bucket_thresholds
    |> Enum.find(fn {bucket, threshold} -> bucket > 0 and pct <= threshold end)
    |> case do
      {bucket, _} -> bucket
      nil -> nil
    end
  end
end
