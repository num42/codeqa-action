defmodule CodeQA.Metrics.File.FileMetric do
  @moduledoc """
  Behaviour for metrics that analyze a single source file.

  Implementations receive a `CodeQA.Engine.FileContext` struct containing
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
  @callback analyze(CodeQA.Engine.FileContext.t()) :: map()

  @doc "List of metric keys returned by analyze/1."
  @callback keys() :: [String.t()]

  @doc "Human-readable description of what this metric measures."
  @callback description() :: String.t()

  @doc "Whether this metric is enabled. Defaults to true when not implemented."
  @callback enabled?() :: boolean()

  @doc """
  Subtractive leave-one-out path. When implemented, the block-impact analyzer
  uses this instead of a full re-run on the file-minus-block reconstruction: it
  derives the new metric values from the unchanged whole-file baseline plus the
  removed block's own context.

  `block_ctx` is a `FileContext` built once per node over the block's verbatim
  original source (`FileImpact.slice_without_original/2`), shared across every
  subtractive metric — so the block's identifiers, tokens, and content are
  extracted by the same pipeline as the baseline. Counts subtract exactly only
  because the slice is byte-exact and block cuts fall on token boundaries.

  Must return the same map shape as `analyze/1` and produce values bit-equal to
  what `analyze/1` would yield on the file-minus-block content. The
  `subtractive_loo` goldfile test asserts this against real sample blocks.
  """
  @callback analyze_loo(baseline :: map(), block_ctx :: CodeQA.Engine.FileContext.t()) :: map()

  @optional_callbacks [description: 0, enabled?: 0, analyze_loo: 2]
end
