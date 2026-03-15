defmodule CodeQA.Metrics.NearDuplicateBlocksFile do
  @moduledoc """
  Counts near-duplicate and exact-duplicate natural code blocks within a single file.

  Blocks are detected at blank-line boundaries with sub-block detection via bracket rules.
  Distance is a percentage of the smaller block's token count, bucketed d0–d8.
  Also reports block_count and sub_block_count as standalone metrics.
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "near_duplicate_blocks_file"

  @spec keys() :: [String.t()]
  def keys do
    ["block_count", "sub_block_count"] ++ for(d <- 0..8, do: "near_dup_block_d#{d}")
  end

  @impl true
  def analyze(ctx) do
    path = Map.get(ctx, :path, "unknown")
    CodeQA.Metrics.NearDuplicateBlocks.analyze([{path, ctx.content}], [])
    |> Map.reject(fn {k, _} -> String.ends_with?(k, "_pairs") end)
  end
end
