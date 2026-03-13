defmodule CodeQA.Metrics.FileMetric do
  @moduledoc """
  Behaviour for metrics that analyze a single source file.

  Implementations receive a `CodeQA.Pipeline.FileContext` struct containing
  pre-parsed data (tokens, identifiers, lines, etc.) and return a map of
  metric key-value pairs.

  See [software metrics](https://en.wikipedia.org/wiki/Software_metric).
  """

  @callback name() :: String.t()
  @callback analyze(CodeQA.Pipeline.FileContext.t()) :: map()
end
