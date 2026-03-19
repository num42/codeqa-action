defmodule CodeQA.Metrics.PostProcessing.PostProcessingMetric do
  @moduledoc """
  Behaviour for post-processing metrics that derive values from the full pipeline result.

  Post-processing metrics run after both file and codebase metrics complete. They receive
  the full result tree and the raw files map, and return a partial result map that is
  deep-merged into the pipeline result.
  """

  @doc "Unique name used as the key in the output."
  @callback name() :: String.t()

  @doc """
  Analyze the pipeline result and return a partial result map to be deep-merged.

  The returned map should use the same top-level structure as the pipeline result:
  `%{"files" => %{path => additions}, "codebase" => additions}`.
  Only keys present in the return value are merged; absent keys are left unchanged.
  """
  @callback analyze(pipeline_result :: map(), files_map :: map(), opts :: keyword()) :: map()
end
