defmodule CodeQA.Metrics.File.NearDuplicateBlocks.Candidates do
  @moduledoc """
  Block fingerprinting, indexing, and candidate-pair matching for near-duplicate detection.

  Handles:
  - Canonical token-value extraction (stripping leading/trailing whitespace tokens)
  - Exact-hash and shingle indexes for fast candidate lookup
  - IDF-based bigram pruning to reduce structural-noise candidates
  - Structural compatibility checks (child-count and line-ratio guards)
  - Pair scoring and bucketing
  """

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Lexing.{NewlineToken, WhitespaceToken}
  alias CodeQA.Metrics.File.NearDuplicateBlocks.Distance

  # Pre-compute token kind strings to avoid repeated function calls in the hot path.
  @nl_kind NewlineToken.kind()
  @ws_kind WhitespaceToken.kind()

  @doc """
  Decorate a list of blocks with pre-computed canonical values, hashes, bigrams, and
  structural metadata. Each entry is an 8-tuple:

      {index, block, values, hash, len_values, children_count, newline_count, bigrams}
  """
  @spec decorate([term()]) :: [tuple()]
  def decorate(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.map(fn {block, i} ->
      values = canonical_values(NodeProtocol.flat_tokens(block))
      children_count = length(NodeProtocol.children(block))
      newline_count = Enum.count(values, &(&1 == @nl_kind))
      bigrams = Enum.chunk_every(values, 2, 1, :discard)

      {i, block, values, :erlang.phash2(values), length(values), children_count, newline_count,
       bigrams}
    end)
  end

  @doc """
  Build both exact (hash → [idx]) and shingle (bigram_hash → [idx]) indexes in one pass,
  using the pre-computed values from the decorated list.
  """
  @spec build_indexes([tuple()]) :: {map(), map()}
  def build_indexes(decorated) do
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

  @doc """
  Returns the set of bigram hashes that appear in more than `max_freq` fraction of blocks.

  Minimum threshold of 2 so a bigram must appear in 3+ blocks before being pruned —
  prevents over-pruning when the total block count is very small.
  """
  @spec compute_frequent_bigrams([tuple()], float()) :: MapSet.t()
  def compute_frequent_bigrams(decorated, max_freq) do
    total = length(decorated)
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

  @doc "Remove bigrams whose hash is in the pruned set from a decorated tuple."
  @spec prune_bigrams(tuple(), MapSet.t()) :: tuple()
  def prune_bigrams({i, b, v, h, l, c, n, bigrams}, pruned) do
    {i, b, v, h, l, c, n, Enum.reject(bigrams, &MapSet.member?(pruned, :erlang.phash2(&1)))}
  end

  @doc """
  Find all near-duplicate pairs for a single block against the full decorated array.
  Returns a list of `{bucket, {label_a, label_b}}` pairs.
  """
  @spec find_pairs_for_block(tuple(), tuple(), map(), map()) :: list()
  def find_pairs_for_block(
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

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Strip leading/trailing <NL> and <WS> tokens and extract kind values as strings.
  # Optimised to 3 passes: one reduce (skip leading NL/WS + collect reversed kinds),
  # one drop_while (strip trailing), one :lists.reverse.
  defp canonical_values(tokens) do
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

    reversed
    |> Enum.drop_while(&(&1 == @nl_kind or &1 == @ws_kind))
    |> :lists.reverse()
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
      ed = Distance.token_edit_distance_bounded(values_a, values_b, max_allowed)

      case Distance.percent_bucket(ed, min_count) do
        nil -> []
        bucket when bucket > 0 -> [{bucket, {block_a.label, block_b.label}}]
        # ed=0 handled by exact_pairs above
        _ -> []
      end
    else
      []
    end
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
end
