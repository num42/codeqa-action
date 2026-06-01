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

  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Language
  alias CodeQA.Metrics.File.NearDuplicateBlocks.Candidates
  alias CodeQA.Metrics.File.NearDuplicateBlocks.Distance

  @max_bucket 8

  # ---------------------------------------------------------------------------
  # Public API — distance helpers delegated to Distance submodule
  # ---------------------------------------------------------------------------

  @doc "Standard Levenshtein distance between two token lists."
  @spec token_edit_distance([String.t()], [String.t()]) :: non_neg_integer()
  defdelegate token_edit_distance(a, b), to: Distance

  @doc "Map an edit distance and min token count to a percentage bucket 0–8, or nil if > 50%."
  @spec percent_bucket(non_neg_integer(), non_neg_integer()) :: 0..8 | nil
  defdelegate percent_bucket(ed, min_count), to: Distance

  # ---------------------------------------------------------------------------
  # Public API — analysis entry points
  # ---------------------------------------------------------------------------

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

  @doc false
  def label_blocks(blocks, path) do
    Enum.map(blocks, fn block ->
      label = if block.start_line, do: "#{path}:#{block.start_line}", else: path
      %{block | label: label}
    end)
  end

  # ---------------------------------------------------------------------------
  # Internal pair-finding pipeline
  # ---------------------------------------------------------------------------

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
      decorated = Candidates.decorate(blocks)

      # sub_block_count derived from the already-computed children_count in decorated.
      sub_block_count =
        Enum.reduce(decorated, 0, fn {_, _, _, _, _, cc, _, _}, acc -> acc + cc end)

      # IDF: prune bigrams that appear in more than idf_max_freq fraction of blocks.
      # These are structural noise (e.g. "end nil", "return false") that inflate the
      # candidate set without helping identify true duplicates.
      pruned = Candidates.compute_frequent_bigrams(decorated, idf_max_freq)

      decorated =
        if MapSet.size(pruned) > 0 do
          Enum.map(decorated, &Candidates.prune_bigrams(&1, pruned))
        else
          decorated
        end

      {exact_index, shingle_index} = Candidates.build_indexes(decorated)

      total = length(decorated)
      # Convert to tuple for O(1) indexed lookup inside the hot comparison loop.
      decorated_arr = List.to_tuple(decorated)

      if has_progress,
        do: IO.puts(:stderr, "  Comparing #{total} blocks for near-duplicates...")

      raw_pairs =
        decorated
        |> Flow.from_enumerable(max_demand: 10, stages: workers)
        |> Flow.flat_map(
          &Candidates.find_pairs_for_block(&1, decorated_arr, exact_index, shingle_index)
        )
        |> Enum.to_list()

      {bucket_pairs(raw_pairs, max_pairs), sub_block_count}
    end
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

  defp format_pairs(pairs) do
    Enum.map(pairs, fn {label_a, label_b} ->
      %{"source_a" => label_a, "source_b" => label_b}
    end)
  end
end
