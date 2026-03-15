defmodule CodeQA.Metrics.NearDuplicateBlocks do
  @moduledoc """
  Near-duplicate block detection using natural code blocks.

  Detects blocks via blank-line boundaries and sub-blocks via bracket/indentation rules.
  Compares structurally similar blocks by token-level edit distance, bucketed as a
  percentage of the smaller block's token count.

  Distance buckets:
    d0 = exact (0%), d1 ≤ 5%, d2 ≤ 10%, d3 ≤ 15%, d4 ≤ 20%,
    d5 ≤ 25%, d6 ≤ 30%, d7 ≤ 40%, d8 ≤ 50%
  """

  alias CodeQA.Metrics.{Block, BlockDetector, TokenNormalizer}

  @max_bucket 8
  @bucket_thresholds [{0, 0.0}, {1, 0.05}, {2, 0.10}, {3, 0.15}, {4, 0.20},
                      {5, 0.25}, {6, 0.30}, {7, 0.40}, {8, 0.50}]

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

  @doc """
  Analyze a list of `{path, content}` pairs for near-duplicate blocks.
  Returns count keys `near_dup_block_d0..d8`, `block_count`, `sub_block_count`.
  With `include_pairs: true` in opts, also returns `_pairs` keys.
  """
  @dialyzer {:nowarn_function, analyze: 2}
  @spec analyze([{String.t(), String.t()}], keyword()) :: map()
  def analyze(labeled_content, opts) do
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)
    include_pairs = Keyword.get(opts, :include_pairs, false)

    # Detect blocks per file, flatten into a labeled list
    all_blocks =
      Enum.flat_map(labeled_content, fn {path, content} ->
        language = BlockDetector.language_from_path(path)
        tokens = TokenNormalizer.normalize_structural(content)
        blocks = BlockDetector.detect_blocks(tokens, language: language)
        Enum.map(blocks, &%{&1 | label: path})
      end)

    block_count = length(all_blocks)
    sub_block_count = Enum.sum(Enum.map(all_blocks, &Block.sub_block_count/1))

    buckets = find_pairs(all_blocks, workers: workers, max_pairs_per_bucket: max_pairs)

    result =
      for d <- 0..@max_bucket, into: %{} do
        {"near_dup_block_d#{d}", Map.get(buckets, d, %{count: 0}).count}
      end

    result = Map.merge(result, %{"block_count" => block_count, "sub_block_count" => sub_block_count})

    case include_pairs do
      true ->
        pairs_result =
          for d <- 0..@max_bucket, into: %{} do
            {"near_dup_block_d#{d}_pairs", Map.get(buckets, d, %{pairs: []}).pairs |> format_pairs()}
          end
        Map.merge(result, pairs_result)
      false ->
        result
    end
  end

  @doc "Find near-duplicate pairs across a list of %Block{} structs."
  @spec find_pairs([Block.t()], keyword()) :: map()
  def find_pairs(blocks, opts) do
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)

    if length(blocks) < 2 do
      %{}
    else
      exact_index = build_exact_index(blocks)
      shingle_index = build_shingle_index(blocks)

      blocks
      |> Enum.with_index()
      |> Task.async_stream(
        &find_pairs_for_block(&1, blocks, exact_index, shingle_index),
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, pairs} -> pairs end)
      |> bucket_pairs(max_pairs)
    end
  end

  # Strip leading/trailing <NL> and <WS> tokens for canonical comparison.
  # This ensures blocks split at blank-line boundaries compare as equal
  # even if trailing newlines differ between first and last blocks.
  defp canonical_tokens(tokens) do
    tokens
    |> Enum.drop_while(&(&1 in ["<NL>", "<WS>"]))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 in ["<NL>", "<WS>"]))
    |> Enum.reverse()
  end

  defp build_exact_index(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {block, idx}, acc ->
      h = :erlang.phash2(canonical_tokens(block.tokens))
      Map.update(acc, h, [idx], &[idx | &1])
    end)
  end

  defp build_shingle_index(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {block, idx}, acc ->
      canonical_tokens(block.tokens)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(acc, fn bigram, sh_acc ->
        h = :erlang.phash2(bigram)
        Map.update(sh_acc, h, [idx], &[idx | &1])
      end)
    end)
  end

  defp find_pairs_for_block({block_a, i}, blocks, exact_index, shingle_index) do
    tokens_a = canonical_tokens(block_a.tokens)
    hash_a = :erlang.phash2(tokens_a)
    exact_set = MapSet.new(Map.get(exact_index, hash_a, []))

    # For d0 (exact), find hash-matching blocks and confirm with token equality
    # to guard against phash2 collisions.
    exact_pairs =
      Map.get(exact_index, hash_a, [])
      |> Enum.filter(&(&1 > i))
      |> Enum.map(fn j ->
        block_b = Enum.at(blocks, j)
        tokens_b = canonical_tokens(block_b.tokens)
        if tokens_b == tokens_a and structure_compatible?(block_a, block_b) do
          {0, {block_a.label, block_b.label}}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # For d1-d8 (near), use shingle index to find candidates.
    min_shared = max(0, round(length(tokens_a) * 0.5) - 1)

    near_pairs =
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
      |> Enum.reject(&MapSet.member?(exact_set, &1))
      |> Enum.flat_map(fn j ->
        block_b = Enum.at(blocks, j)
        tokens_b = canonical_tokens(block_b.tokens)

        if structure_compatible?(block_a, block_b) do
          ed = token_edit_distance(tokens_a, tokens_b)
          min_count = min(length(tokens_a), length(tokens_b))
          case percent_bucket(ed, min_count) do
            nil -> []
            bucket when bucket > 0 -> [{bucket, {block_a.label, block_b.label}}]
            _ -> []  # ed=0 handled by exact_pairs above
          end
        else
          []
        end
      end)

    exact_pairs ++ near_pairs
  end

  defp canonical_line_count(tokens) do
    tokens
    |> canonical_tokens()
    |> Enum.count(&(&1 == "<NL>"))
    |> Kernel.+(1)
  end

  defp structure_compatible?(a, b) do
    sub_diff = abs(Block.sub_block_count(a) - Block.sub_block_count(b))
    lines_a = canonical_line_count(a.tokens)
    lines_b = canonical_line_count(b.tokens)
    max_lines = max(lines_a, lines_b)
    line_ratio = if max_lines > 0, do: abs(lines_a - lines_b) / max_lines, else: 0.0
    sub_diff <= 1 and line_ratio <= 0.30
  end

  defp bucket_pairs(raw_pairs, max_pairs) do
    Enum.reduce(raw_pairs, %{}, fn {bucket, pair}, acc ->
      Map.update(acc, bucket, %{count: 1, pairs: maybe_append([], pair, max_pairs)}, fn existing ->
        %{count: existing.count + 1, pairs: maybe_append(existing.pairs, pair, max_pairs)}
      end)
    end)
  end

  defp maybe_append(list, _pair, max) when is_integer(max) and length(list) >= max, do: list
  defp maybe_append(list, pair, _max), do: [pair | list]

  defp format_pairs(pairs) do
    Enum.map(pairs, fn {label_a, label_b} ->
      %{"source_a" => label_a, "source_b" => label_b}
    end)
  end
end
