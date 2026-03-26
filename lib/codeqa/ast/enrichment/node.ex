defmodule CodeQA.AST.Enrichment.Node do
  @moduledoc """
  A detected code node with optional nested sub-blocks.

  ## Fields

  - `tokens`      — aggregated code content: for leaf nodes, the original token stream;
                    for non-leaf nodes, the flat concatenation of all children's `tokens`.
                    Use this for content comparison and metrics.
  - `line_count`  — number of source lines spanned by this node: `end_line - start_line + 1`
                    when both are available, else `1`.
  - `children`    — nested `Node.t()` structs detected by enclosure rules
                    (`BracketRule`, `ColonIndentationRule`).
  - `label`       — arbitrary term attached by the caller. Set to `"path:start_line"`
                    by `NearDuplicateBlocks.analyze/2` for human-readable pair reporting.
  - `start_line`  — 1-based line number of the first token in this node, populated by
                    `Parser` from `List.first(tokens).line`.
  - `end_line`    — 1-based line number of the last token in this node, populated by
                    `Parser` from `List.last(tokens).line`.

  `start_line` and `end_line` may be `nil` for synthetic nodes created in tests
  without line metadata.
  """

  @enforce_keys [:tokens, :line_count, :children]
  defstruct [
    :tokens,
    :line_count,
    :children,
    :label,
    :start_line,
    :end_line,
    type: :code
  ]

  @type t :: %__MODULE__{
          tokens: [CodeQA.AST.Lexing.Token.t()],
          line_count: non_neg_integer(),
          children: [term()],
          label: term() | nil,
          start_line: non_neg_integer() | nil,
          end_line: non_neg_integer() | nil,
          type: :code | :doc | :typespec
        }

  @spec children_count(t()) :: non_neg_integer()
  def children_count(%__MODULE__{children: ch}), do: length(ch)

  # Keep old name as deprecated alias during transition
  @spec sub_block_count(t()) :: non_neg_integer()
  def sub_block_count(%__MODULE__{children: ch}), do: length(ch)

  @spec token_count(t()) :: non_neg_integer()
  def token_count(%__MODULE__{tokens: tokens}), do: length(tokens)
end

defimpl CodeQA.AST.Classification.NodeProtocol, for: CodeQA.AST.Enrichment.Node do
  def tokens(n), do: n.tokens
  def line_count(n), do: n.line_count
  def children(n), do: n.children
  def start_line(n), do: n.start_line
  def end_line(n), do: n.end_line
  def label(n), do: n.label

  def flat_tokens(n) do
    if Enum.empty?(n.children),
      do: n.tokens,
      else: Enum.flat_map(n.children, &CodeQA.AST.Classification.NodeProtocol.flat_tokens/1)
  end
end
