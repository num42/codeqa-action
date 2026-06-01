defmodule CodeQA.Metrics.Codebase.CodebaseMetric do
  @moduledoc """
  Behaviour for metrics that operate across an entire codebase.

  Unlike `FileMetric`, which analyzes a single file, codebase metrics receive
  a map of all source files and can compute cross-file properties such as
  duplication or structural similarity.

  See [software metrics](https://en.wikipedia.org/wiki/Software_metric).
  """

  @callback name() :: String.t()
  @callback analyze(%{String.t() => String.t()}, keyword()) :: map()
end
