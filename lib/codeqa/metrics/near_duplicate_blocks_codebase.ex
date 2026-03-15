defmodule CodeQA.Metrics.NearDuplicateBlocksCodebase do
  @moduledoc """
  Counts near-duplicate and exact-duplicate natural code blocks across the codebase.

  Detects blocks per file, pools them, and finds pairs across all files.
  Includes pair source lists (capped by max_pairs_per_bucket).

  Configure in .codeqa.yml:
      near_duplicate_blocks:
        max_pairs_per_bucket: 50
  """

  @behaviour CodeQA.Metrics.CodebaseMetric

  @impl true
  def name, do: "near_duplicate_blocks_codebase"

  @impl true
  def analyze(files, opts \\ []) do
    ndb_opts = Keyword.get(opts, :near_duplicate_blocks, [])
    max_pairs = Keyword.get(ndb_opts, :max_pairs_per_bucket, nil)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    CodeQA.Metrics.NearDuplicateBlocks.analyze(
      Map.to_list(files),
      include_pairs: true,
      max_pairs_per_bucket: max_pairs,
      workers: workers
    )
    |> Map.reject(fn {k, _} -> k in ["block_count", "sub_block_count"] end)
  end
end
