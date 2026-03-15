defmodule CodeQA.Metrics.Block do
  @moduledoc "A detected code block with optional nested sub-blocks."

  @enforce_keys [:tokens, :line_count, :sub_blocks]
  defstruct [:tokens, :line_count, :sub_blocks, :label]

  @type t :: %__MODULE__{
    tokens: [String.t()],
    line_count: non_neg_integer(),
    sub_blocks: [t()],
    label: term() | nil
  }

  @spec sub_block_count(t()) :: non_neg_integer()
  def sub_block_count(%__MODULE__{sub_blocks: sbs}), do: length(sbs)

  @spec token_count(t()) :: non_neg_integer()
  def token_count(%__MODULE__{tokens: tokens}), do: length(tokens)
end
