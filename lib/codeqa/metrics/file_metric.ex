defmodule CodeQA.Metrics.FileMetric do
  @moduledoc """
  Behaviour for metrics that analyze a single source file.

  Implementations receive a `CodeQA.Pipeline.FileContext` struct containing
  pre-parsed data (tokens, identifiers, lines, etc.) and return a map of
  metric key-value pairs. On error, return an empty map `%{}` rather than
  raising.

  ## Minimal implementation

      defmodule MyMetric do
        @behaviour CodeQA.Metrics.FileMetric

        @impl true
        def name, do: "my_metric"

        @impl true
        def analyze(ctx) do
          %{"value" => compute(ctx)}
        end
      end

  See [software metrics](https://en.wikipedia.org/wiki/Software_metric).
  """

  @callback name() :: String.t()
  @callback analyze(CodeQA.Pipeline.FileContext.t()) :: map()

  @doc "List of metric keys returned by analyze/1."
  @callback keys() :: [String.t()]

  @doc "Human-readable description of what this metric measures."
  @callback description() :: String.t()

  @doc "Whether this metric is enabled. Defaults to true when not implemented."
  @callback enabled?() :: boolean()

  @optional_callbacks [description: 0, enabled?: 0]
end
