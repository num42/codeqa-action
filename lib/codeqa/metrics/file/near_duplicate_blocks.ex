defmodule CodeQA.Metrics.File.NearDuplicateBlocks do
  @moduledoc """
  Near-duplicate block detection using natural code blocks.

  Detects blocks via blank-line boundaries and sub-blocks via bracket/indentation rules.
  Compares structurally similar blocks by token-level edit distance, bucketed as a
  percentage of the smaller block's token count.

  Distance buckets:
    d0 = exact (0%), d1 ≤ 5%, d2 ≤ 10%, d3 ≤ 15%, d4 ≤ 20%,
    d5 ≤ 25%, d6 ≤ 30%, d7 ≤ 40%, d8 ≤ 50%
  """

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.{NewlineToken, WhitespaceToken}
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Language

  @max_bucket 8
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

  # Pre-compute token kind strings to avoid repeated function calls in the hot path.
  @nl_kind NewlineToken.kind()
  @ws_kind WhitespaceToken.kind()

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
  defp token_edit_distance_bounded([], b, _max), do: length(b)
  defp token_edit_distance_bounded(a, [], _max), do: length(a)

  defp token_edit_distance_bounded(a, b, max_distance) do
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

  defp levenshtein_cols_with_min(_b, lb, _prev, _ai, acc_and_min, j) when j > lb, do: acc_and_min

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

  @doc """
  Analyze a list of `{path, content}` pairs for near-duplicate blocks.
  Returns count keys `near_dup_block_d0..d8`, `block_count`, `sub_block_count`.
  With `include_pairs: true` in opts, also returns `_pairs` keys.
  """
  @dialyzer {:nowarn_function, analyze: 2}
  @spec analyze([{String.t(), String.t()}], keyword()) :: map()
  def analyze(labeled_content, opts) do
    all_blocks =
      Enum.flat_map(labeled_content, fn {path, content} ->
        lang_mod = Language.detect(path)
        tokens = TokenNormalizer.normalize_structural(content)

        Parser.detect_blocks(tokens, lang_mod)
        |> label_blocks(path)
      end)

    analyze_from_blocks(all_blocks, opts)
  end

  @doc """
  Analyze a pre-built list of labeled `Node.t()` structs for near-duplicate blocks.
  Skips tokenization and block detection — use when blocks are already available.
  Returns the same keys as `analyze/2`.
  """
  @dialyzer {:nowarn_function, analyze_from_blocks: 2}
  @spec analyze_from_blocks([Node.t()], keyword()) :: map()
  def analyze_from_blocks(all_blocks, opts) do
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)
    include_pairs = Keyword.get(opts, :include_pairs, false)

    block_count = length(all_blocks)

    find_pairs_opts =
      [workers: workers, max_pairs_per_bucket: max_pairs] ++
        Keyword.take(opts, [:on_progress, :idf_max_freq])

    # do_find_pairs computes sub_block_count from the decorated list it already
    # builds, eliminating the separate NodeProtocol.children pass.
    {buckets, sub_block_count} = do_find_pairs(all_blocks, find_pairs_opts)

    result =
      for d <- 0..@max_bucket, into: %{} do
        {"near_dup_block_d#{d}", Map.get(buckets, d, %{count: 0}).count}
      end

    result =
      Map.merge(result, %{"block_count" => block_count, "sub_block_count" => sub_block_count})

    case include_pairs do
      true ->
        pairs_result =
          for d <- 0..@max_bucket, into: %{} do
            {"near_dup_block_d#{d}_pairs",
             Map.get(buckets, d, %{pairs: []}).pairs |> format_pairs()}
          end

        Map.merge(result, pairs_result)

      false ->
        result
    end
  end

  @doc "Find near-duplicate pairs across a list of %Node{} structs."
  @spec find_pairs([Node.t()], keyword()) :: map()
  def find_pairs(blocks, opts) do
    {buckets, _sub_block_count} = do_find_pairs(blocks, opts)
    buckets
  end

  # Internal implementation returning {buckets, sub_block_count} so that
  # analyze_from_blocks gets both without a redundant NodeProtocol.children pass.
  defp do_find_pairs(blocks, opts) do
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)
    idf_max_freq = Keyword.get(opts, :idf_max_freq, 1.0)
    has_progress = Keyword.has_key?(opts, :on_progress)

    if length(blocks) < 2 do
      {%{}, 0}
    else
      # Pre-compute canonical values and hashes once per block. Each decorated entry
      # is {index, block, values, hash, len_values, children_count, newline_count, bigrams}
      # so downstream functions never recompute them.
      decorated =
        blocks
        |> Enum.with_index()
        |> Enum.map(fn {block, i} ->
          values = canonical_values(NodeProtocol.flat_tokens(block))
          children_count = length(NodeProtocol.children(block))
          newline_count = Enum.count(values, &(&1 == @nl_kind))
          bigrams = Enum.chunk_every(values, 2, 1, :discard)

          {i, block, values, :erlang.phash2(values), length(values), children_count,
           newline_count, bigrams}
        end)

      # sub_block_count derived from the already-computed children_count in decorated.
      sub_block_count =
        Enum.reduce(decorated, 0, fn {_, _, _, _, _, cc, _, _}, acc -> acc + cc end)

      # IDF: prune bigrams that appear in more than idf_max_freq fraction of blocks.
      # These are structural noise (e.g. "end nil", "return false") that inflate the
      # candidate set without helping identify true duplicates.
      pruned = compute_frequent_bigrams(decorated, idf_max_freq)

      decorated =
        if MapSet.size(pruned) > 0 do
          Enum.map(decorated, &prune_bigrams(&1, pruned))
        else
          decorated
        end

      {exact_index, shingle_index} = build_indexes(decorated)

      total = length(decorated)
      # Convert to tuple for O(1) indexed lookup inside the hot comparison loop.
      decorated_arr = List.to_tuple(decorated)

      if has_progress,
        do: IO.puts(:stderr, "  Comparing #{total} blocks for near-duplicates...")

      raw_pairs =
        decorated
        |> Flow.from_enumerable(max_demand: 10, stages: workers)
        |> Flow.flat_map(&find_pairs_for_block(&1, decorated_arr, exact_index, shingle_index))
        |> Enum.to_list()

      {bucket_pairs(raw_pairs, max_pairs), sub_block_count}
    end
  end

  # Returns the set of bigram hashes that appear in more than max_freq fraction of blocks.
  defp compute_frequent_bigrams(decorated, max_freq) do
    total = length(decorated)
    # Minimum threshold of 2 so a bigram must appear in 3+ blocks before being
    # pruned — prevents over-pruning when the total block count is very small
    # (e.g. with 2 blocks, any shared bigram would otherwise always be pruned).
    threshold = max(2, round(total * max_freq))

    decorated
    |> Enum.reduce(%{}, fn {_, _, _, _, _, _, _, bigrams}, acc ->
      bigrams
      |> Enum.uniq_by(&:erlang.phash2/1)
      |> Enum.reduce(acc, fn bigram, a ->
        Map.update(a, :erlang.phash2(bigram), 1, &(&1 + 1))
      end)
    end)
    |> Enum.filter(fn {_, count} -> count > threshold end)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
  end

  # Strip leading/trailing <NL> and <WS> tokens and extract kind values as strings.
  # This ensures blocks split at blank-line boundaries compare as equal
  # even if trailing newlines differ between first and last blocks.
  # Returns [String.t()] (kinds only) so hashing, comparison, and edit distance
  # are independent of token line/col metadata.
  #
  # Optimised to 3 passes: one reduce (skip leading NL/WS + collect reversed kinds),
  # one drop_while (strip trailing from the reversed list), one :lists.reverse.
  defp canonical_values(tokens) do
    # Pass 1: skip leading NL/WS while building a reversed kinds list.
    {reversed, _in_content} =
      Enum.reduce(tokens, {[], false}, fn t, {acc, in_content} ->
        kind = t.kind
        is_skip = kind == @nl_kind or kind == @ws_kind

        if in_content or not is_skip do
          {[kind | acc], true}
        else
          {acc, false}
        end
      end)

    # Pass 2: drop trailing NL/WS (which appear as leading in the reversed list).
    # Pass 3: reverse back to source order via native BIF.
    reversed
    |> Enum.drop_while(&(&1 == @nl_kind or &1 == @ws_kind))
    |> :lists.reverse()
  end

  # Build both exact (hash → [idx]) and shingle (bigram_hash → [idx]) indexes in one pass,
  # using the pre-computed values from the decorated list.
  defp build_indexes(decorated) do
    Enum.reduce(decorated, {%{}, %{}}, fn {idx, _block, _values, hash, _len, _children, _newlines,
                                           bigrams},
                                          {exact_acc, shingle_acc} ->
      exact_acc = Map.update(exact_acc, hash, [idx], &[idx | &1])

      shingle_acc =
        bigrams
        |> Enum.reduce(shingle_acc, fn bigram, sh_acc ->
          h = :erlang.phash2(bigram)
          Map.update(sh_acc, h, [idx], &[idx | &1])
        end)

      {exact_acc, shingle_acc}
    end)
  end

  defp find_pairs_for_block(
         {i, block_a, values_a, hash_a, len_a, children_a, newlines_a, bigrams_a},
         decorated_arr,
         exact_index,
         shingle_index
       ) do
    # For small exact-match lists (typically 0–3 entries) a plain list membership
    # check avoids the overhead of constructing a MapSet.
    exact_list = Map.get(exact_index, hash_a, [])

    # For d0 (exact), find hash-matching blocks and confirm with value equality
    # to guard against phash2 collisions.
    exact_pairs =
      exact_list
      |> Enum.filter(&(&1 > i))
      |> Enum.map(fn j ->
        {_j, block_b, values_b, _hash_b, _len_b, children_b, newlines_b, _bigrams_b} =
          elem(decorated_arr, j)

        if values_b == values_a and
             structure_compatible?(children_a, newlines_a, children_b, newlines_b) do
          {0, {block_a.label, block_b.label}}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # For d1-d8 (near), use shingle index to find candidates.
    min_shared = max(0, round(len_a * 0.5) - 1)

    near_pairs =
      bigrams_a
      |> Enum.reduce(%{}, fn bigram, acc ->
        h = :erlang.phash2(bigram)
        Map.get(shingle_index, h, []) |> Enum.reduce(acc, &count_candidate(&1, &2, i))
      end)
      |> Enum.filter(fn {_, count} -> count >= min_shared end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.reject(fn j -> j in exact_list end)
      |> Enum.flat_map(fn j ->
        near_pair_for_candidate(
          j,
          decorated_arr,
          block_a,
          values_a,
          len_a,
          children_a,
          newlines_a
        )
      end)

    exact_pairs ++ near_pairs
  end

  defp count_candidate(j, cnt, i) when j > i, do: Map.update(cnt, j, 1, &(&1 + 1))
  defp count_candidate(_j, cnt, _i), do: cnt

  defp near_pair_for_candidate(j, decorated_arr, block_a, values_a, len_a, children_a, newlines_a) do
    {_j, block_b, values_b, _hash_b, len_b, children_b, newlines_b, _bigrams_b} =
      elem(decorated_arr, j)

    min_count = min(len_a, len_b)
    max_allowed = round(min_count * 0.5)

    if structure_compatible?(children_a, newlines_a, children_b, newlines_b) and
         abs(len_a - len_b) <= max_allowed do
      ed = token_edit_distance_bounded(values_a, values_b, max_allowed)

      case percent_bucket(ed, min_count) do
        nil -> []
        bucket when bucket > 0 -> [{bucket, {block_a.label, block_b.label}}]
        # ed=0 handled by exact_pairs above
        _ -> []
      end
    else
      []
    end
  end

  defp prune_bigrams({i, b, v, h, l, c, n, bigrams}, pruned) do
    {i, b, v, h, l, c, n, Enum.reject(bigrams, &MapSet.member?(pruned, :erlang.phash2(&1)))}
  end

  # Uses pre-computed children counts and newline counts from the decorated tuple
  # so NodeProtocol.children/1 and Enum.count/2 are not called per candidate pair.
  defp structure_compatible?(children_a, newlines_a, children_b, newlines_b) do
    sub_diff = abs(children_a - children_b)
    lines_a = newlines_a + 1
    lines_b = newlines_b + 1
    max_lines = max(lines_a, lines_b)
    line_ratio = if max_lines > 0, do: abs(lines_a - lines_b) / max_lines, else: 0.0
    sub_diff <= 1 and line_ratio <= 0.30
  end

  defp bucket_pairs(raw_pairs, max_pairs) do
    Enum.reduce(raw_pairs, %{}, fn {bucket, pair}, acc ->
      Map.update(
        acc,
        bucket,
        %{count: 1, pairs: maybe_append([], pair, max_pairs, 0)},
        fn existing ->
          %{
            count: existing.count + 1,
            pairs: maybe_append(existing.pairs, pair, max_pairs, existing.count)
          }
        end
      )
    end)
  end

  # Uses the already-tracked count instead of length(list) to avoid an O(n) walk.
  defp maybe_append(list, _pair, max, count) when is_integer(max) and count >= max, do: list
  defp maybe_append(list, pair, _max, _count), do: [pair | list]

  @doc false
  def label_blocks(blocks, path) do
    Enum.map(blocks, fn block ->
      label = if block.start_line, do: "#{path}:#{block.start_line}", else: path
      %{block | label: label}
    end)
  end

  defp format_pairs(pairs) do
    Enum.map(pairs, fn {label_a, label_b} ->
      %{"source_a" => label_a, "source_b" => label_b}
    end)
  end
end
