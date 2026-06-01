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
          content: String.t(),
          tokens: [CodeQA.Engine.Pipeline.Token.t()],
          token_counts: map(),
          words: list(),
          identifiers: list(),
          lines: list(),
          encoded: String.t(),
          byte_count: non_neg_integer(),
          line_count: non_neg_integer(),
          path: String.t() | nil,
          blocks: [CodeQA.AST.Enrichment.Node.t()] | nil
        }
end
