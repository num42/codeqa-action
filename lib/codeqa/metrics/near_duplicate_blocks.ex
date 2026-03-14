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

  @doc "Extract overlapping token blocks with 50% stride. Returns [{block_tokens, token_offset}]."
  @spec extract_blocks([String.t()], pos_integer()) :: [{[String.t()], non_neg_integer()}]
  def extract_blocks(tokens, block_size) when length(tokens) < block_size, do: []

  def extract_blocks(tokens, block_size) do
    stride = max(1, div(block_size, 2))

    tokens
    |> Enum.chunk_every(block_size, stride, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {block, idx} -> {block, idx * stride} end)
  end

  @doc """
  Find near-duplicate pairs across a list of labeled blocks.

  `labeled_blocks` is `[{token_list, label}]` where label is any term stored in pair sources.
  Returns `%{{block_size, distance} => %{count: integer, pairs: [pair]}}`.
  """
  @spec find_pairs([{[String.t()], term()}], keyword()) :: map()
  def find_pairs(labeled_blocks, opts) do
    max_distance = Keyword.get(opts, :max_distance, @max_distance)
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    total = length(labeled_blocks)

    if total < 2 do
      %{}
    else
      exact_index = build_exact_index(labeled_blocks)
      shingle_index = build_shingle_index(labeled_blocks)

      labeled_blocks
      |> Enum.with_index()
      |> Task.async_stream(
        &find_pairs_for_block(&1, labeled_blocks, exact_index, shingle_index, max_distance),
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, pairs} -> pairs end)
      |> bucket_pairs(max_pairs)
    end
  end

  defp build_exact_index(labeled_blocks) do
    labeled_blocks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{tokens, _label}, idx}, acc ->
      h = :erlang.phash2(tokens)
      Map.update(acc, h, [idx], &[idx | &1])
    end)
  end

  defp build_shingle_index(labeled_blocks) do
    labeled_blocks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{tokens, _label}, idx}, acc ->
      tokens
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(acc, fn bigram, sh_acc ->
        h = :erlang.phash2(bigram)
        Map.update(sh_acc, h, [idx], &[idx | &1])
      end)
    end)
  end

  defp find_pairs_for_block({{tokens_a, label_a}, i}, labeled_blocks, exact_index, shingle_index, max_distance) do
    block_size = length(tokens_a)
    hash_a = :erlang.phash2(tokens_a)
    exact_set = MapSet.new(Map.get(exact_index, hash_a, []))

    min_shared = max(0, block_size - max_distance * 2)

    candidates =
      tokens_a
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(%{}, fn bigram, acc ->
        h = :erlang.phash2(bigram)
        Map.get(shingle_index, h, [])
        |> Enum.reduce(acc, fn j, cnt ->
          if j > i, do: Map.update(cnt, j, 1, &(&1 + 1)), else: cnt
        end)
      end)
      |> Enum.filter(fn {_, count} -> count >= min_shared end)
      |> Enum.map(&elem(&1, 0))

    for j <- candidates,
        not MapSet.member?(exact_set, j) do
      {tokens_b, label_b} = Enum.at(labeled_blocks, j)
      ed = token_edit_distance(tokens_a, tokens_b)

      if ed >= 1 and ed <= max_distance do
        {{block_size, ed}, {label_a, label_b}}
      else
        nil
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  defp bucket_pairs(raw_pairs, max_pairs) do
    Enum.reduce(raw_pairs, %{}, fn {key, pair}, acc ->
      Map.update(acc, key, %{count: 1, pairs: maybe_append([], pair, max_pairs)}, fn existing ->
        %{
          count: existing.count + 1,
          pairs: maybe_append(existing.pairs, pair, max_pairs)
        }
      end)
    end)
  end

  defp maybe_append(list, _pair, max) when is_integer(max) and length(list) >= max, do: list
  defp maybe_append(list, pair, _max), do: [pair | list]
end
