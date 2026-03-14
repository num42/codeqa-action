defmodule CodeQA.Metrics.NearDuplicateBlocksFile do
  @moduledoc """
  Counts near-duplicate token blocks within a single file.

  Blocks are extracted from the normalized token stream (via TokenNormalizer)
  at sizes [8, 16, 32, 64, 128, 256] with 50% stride. Pairs with token-level
  edit distance 1–8 are counted per (block_size, distance) bucket.
  """

  @behaviour CodeQA.Metrics.FileMetric

  @block_sizes [8, 16, 32, 64, 128, 256]
  @max_distance 8

  @impl true
  def name, do: "near_duplicate_blocks_file"

  @spec keys() :: [String.t()]
  def keys do
    for b <- @block_sizes, d <- 1..@max_distance, do: "near_dup_#{b}_d#{d}"
  end

  @impl true
  def analyze(ctx) do
    tokens = CodeQA.Metrics.TokenNormalizer.normalize(ctx.content)
    labeled = [{"file", tokens}]

    CodeQA.Metrics.NearDuplicateBlocks.analyze(labeled, @block_sizes, [])
    |> Map.reject(fn {k, _} -> String.ends_with?(k, "_pairs") end)
  end
end
