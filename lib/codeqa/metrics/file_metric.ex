defmodule CodeQA.Metrics.FileMetric do
  @moduledoc false

  @callback name() :: String.t()
  @callback analyze(CodeQA.Pipeline.FileContext.t()) :: map()
end
