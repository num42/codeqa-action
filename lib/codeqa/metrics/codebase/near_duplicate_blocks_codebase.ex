defmodule CodeQA.Metrics.Codebase.NearDuplicateBlocksCodebase do
  @moduledoc """
  Counts near-duplicate and exact-duplicate natural code blocks across the codebase.

  Detects blocks per file, pools them, and finds pairs across all files.
  Includes pair source lists (capped by max_pairs_per_bucket).

  Configure in .codeqa.yml:
      near_duplicate_blocks:
        max_pairs_per_bucket: 50
  """

  @behaviour CodeQA.Metrics.Codebase.CodebaseMetric

  alias CodeQA.Analysis.FileContextServer
  alias CodeQA.Metrics.File.NearDuplicateBlocks

  @impl true
  def name, do: "near_duplicate_blocks_codebase"

  @impl true
  def analyze(files, opts \\ []) do
    ndb_opts = Keyword.get(opts, :near_duplicate_blocks, [])
    max_pairs = Keyword.get(ndb_opts, :max_pairs_per_bucket, nil)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    ndb_opts =
      [include_pairs: true, max_pairs_per_bucket: max_pairs, workers: workers] ++
        Keyword.take(opts, [:on_progress])

    pid = Keyword.fetch!(opts, :file_context_pid)

    all_blocks =
      Enum.flat_map(files, fn {path, content} ->
        ctx = FileContextServer.get(pid, content, path: path)
        NearDuplicateBlocks.label_blocks(ctx.blocks, path)
      end)

    result = NearDuplicateBlocks.analyze_from_blocks(all_blocks, ndb_opts)

    result
    |> Map.reject(fn {k, _} -> k in ["block_count", "sub_block_count"] end)
  end
end
