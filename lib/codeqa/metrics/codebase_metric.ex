defmodule CodeQA.Metrics.CodebaseMetric do
  @moduledoc """
  Behaviour for metrics that operate across an entire codebase.

  Unlike `FileMetric`, which analyzes a single file, codebase metrics receive
  a map of all source files and can compute cross-file properties such as
  duplication or structural similarity.

  ## Common opts keys

  Implementations may accept keyword options including:
  - `:workers` — number of parallel workers (default: `System.schedulers_online/0`)
  - `:on_progress` — progress callback key (presence enables progress output)

  ## Minimal implementation

      defmodule MyCodebaseMetric do
        @behaviour CodeQA.Metrics.CodebaseMetric

        @impl true
        def name, do: "my_metric"

        @impl true
        def analyze(files, _opts) do
          %{"file_count" => map_size(files)}
        end
      end

  See [software metrics](https://en.wikipedia.org/wiki/Software_metric).
  """

  @typedoc "Map of file path to file content string."
  @type file_map :: %{required(String.t()) => String.t()}

  @callback name() :: String.t()
  @callback analyze(file_map(), keyword()) :: map()

  @doc "Human-readable description of what this metric measures."
  @callback description() :: String.t()

  @optional_callbacks [description: 0]
end
