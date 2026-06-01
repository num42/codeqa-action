defprotocol CodeQA.AST.Classification.NodeProtocol do
  @moduledoc """
  Common interface for all typed AST node structs.

  All node struct types (CodeNode, DocNode, FunctionNode, etc.) implement this
  protocol, allowing downstream code to work with any node type uniformly.
  """

  @spec tokens(t()) :: [term()]
  def tokens(node)

  @spec flat_tokens(t()) :: [term()]
  def flat_tokens(node)

  @spec line_count(t()) :: non_neg_integer()
  def line_count(node)

  @spec children(t()) :: [term()]
  def children(node)

  @spec start_line(t()) :: non_neg_integer() | nil
  def start_line(node)

  @spec end_line(t()) :: non_neg_integer() | nil
  def end_line(node)

  @spec label(t()) :: term() | nil
  def label(node)
end
