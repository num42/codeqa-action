defmodule CodeQA.Engine.FileContext do
  @moduledoc "Immutable pre-computed data shared across all file metrics."
  @enforce_keys [
    :content,
    :tokens,
    :token_counts,
    :words,
    :identifiers,
    :lines,
    :encoded,
    :byte_count,
    :line_count
  ]
  defstruct @enforce_keys ++ [:path, :blocks]

  @type t :: %__MODULE__{
          blocks: [CodeQA.AST.Enrichment.Node.t()] | nil,
          byte_count: non_neg_integer(),
          content: String.t(),
          encoded: String.t(),
          identifiers: list(),
          line_count: non_neg_integer(),
          lines: list(),
          path: String.t() | nil,
          token_counts: map(),
          tokens: [CodeQA.Engine.Pipeline.Token.t()],
          words: list()
        }
end
