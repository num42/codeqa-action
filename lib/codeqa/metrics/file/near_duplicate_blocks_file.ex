defmodule CodeQA.Metrics.File.NearDuplicateBlocksFile do
  @moduledoc """
  Counts near-duplicate and exact-duplicate natural code blocks within a single file.

  Blocks are detected at blank-line boundaries with sub-block detection via bracket rules.
  Distance is a percentage of the smaller block's token count, bucketed d0–d8.
  Also reports block_count and sub_block_count as standalone metrics.
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  alias CodeQA.Metrics.File.NearDuplicateBlocks

  @impl true
  def name, do: "near_duplicate_blocks_file"

  @impl true
  def keys do
    ["block_count", "sub_block_count"] ++ for(d <- 0..8, do: "near_dup_block_d#{d}")
  end

  @impl true
  def analyze(%{path: path, blocks: blocks}) when is_list(blocks) do
    NearDuplicateBlocks.analyze_from_blocks(
      NearDuplicateBlocks.label_blocks(blocks, path || "unknown"),
      []
    )
    |> Map.reject(fn {k, _} -> String.ends_with?(k, "_pairs") end)
  end

  def analyze(ctx) do
    path = ctx.path || "unknown"

    NearDuplicateBlocks.analyze([{path, ctx.content}], [])
    |> Map.reject(fn {k, _} -> String.ends_with?(k, "_pairs") end)
  end
end
