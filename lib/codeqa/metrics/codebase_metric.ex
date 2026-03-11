defmodule CodeQA.Metrics.CodebaseMetric do
  @moduledoc false

  @callback name() :: String.t()
  @callback analyze(%{String.t() => String.t()}, keyword()) :: map()
end
