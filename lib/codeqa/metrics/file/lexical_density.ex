defmodule CodeQA.Metrics.File.LexicalDensity do
  @moduledoc """
  Measures the share of content-bearing tokens among all tokens.

  Content tokens are identifiers and numeric literals — the substance of the
  code. Function tokens are the structural glue: keywords (`do`, `end`, `case`),
  operators and punctuation. High density means information-dense code; low
  density means a lot of scaffolding around little content.

  Complements `Metrics.File.Readability` (Flesch/Fog), which captures surface
  readability but not lexical density.

  See [Lexical density](https://en.wikipedia.org/wiki/Lexical_density).
  """

  alias CodeQA.Engine.FileContext

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "lexical_density"

  @impl true
  def keys, do: ["lexical_density", "content_tokens", "function_tokens"]

  @impl true
  def description,
    do: "Share of content-bearing tokens (identifiers, literals) among all tokens."

  @spec analyze(FileContext.t()) :: map()
  @impl true
  def analyze(%FileContext{tokens: []}) do
    %{"lexical_density" => 0.0, "content_tokens" => 0, "function_tokens" => 0}
  end

  def analyze(%FileContext{tokens: tokens, identifiers: identifiers}) do
    total = length(tokens)
    numeric = Enum.count(tokens, &(&1.kind == "<NUM>"))
    # identifiers comes from the pipeline's keyword-filtered word scan, so
    # keywords land in `function`, not `content`. Clamp guards against a
    # pipeline-side identifier/token divergence yielding a negative count.
    content = min(length(identifiers) + numeric, total)
    function = total - content

    %{
      "lexical_density" => Float.round(content / total, 4),
      "content_tokens" => content,
      "function_tokens" => function
    }
  end
end
