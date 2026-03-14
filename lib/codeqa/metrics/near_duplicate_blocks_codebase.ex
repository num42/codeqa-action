defmodule CodeQA.Metrics.NearDuplicateBlocksCodebase do
  @moduledoc """
  Counts near-duplicate token blocks across the whole codebase.

  Blocks are extracted per-file at sizes [8, 16, 32, 64, 128, 256] with
  50% stride, then pooled for pairwise comparison. Pairs with token-level
  edit distance 1–8 are counted per (block_size, distance) bucket.
  Sources record file path and token offset.

  Configure `max_pairs_per_bucket` in `.codeqa.yml`:

      near_duplicate_blocks:
        max_pairs_per_bucket: 50
  """

  @behaviour CodeQA.Metrics.CodebaseMetric

  @block_sizes [8, 16, 32, 64, 128, 256]

  @impl true
  def name, do: "near_duplicate_blocks_codebase"

  @impl true
  def analyze(files, opts \\ []) do
    ndb_opts = Keyword.get(opts, :near_duplicate_blocks, [])
    max_pairs = Keyword.get(ndb_opts, :max_pairs_per_bucket, nil)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    labeled =
      Enum.map(files, fn {path, content} ->
        tokens = CodeQA.Metrics.TokenNormalizer.normalize(content)
        {path, tokens}
      end)

    CodeQA.Metrics.NearDuplicateBlocks.analyze(
      labeled,
      @block_sizes,
      max_pairs_per_bucket: max_pairs,
      workers: workers
    )
  end
end
