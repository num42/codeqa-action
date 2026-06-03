defmodule CodeQA.AST.Classification.TypedNodeKind do
  @moduledoc "Maps a typed node struct from `NodeClassifier` to its kind atom."

  alias CodeQA.AST.Nodes.AttributeNode
  alias CodeQA.AST.Nodes.CodeNode
  alias CodeQA.AST.Nodes.DocNode
  alias CodeQA.AST.Nodes.FunctionNode
  alias CodeQA.AST.Nodes.ImportNode
  alias CodeQA.AST.Nodes.ModuleNode
  alias CodeQA.AST.Nodes.TestNode

  @type kind :: :doc | :attribute | :function | :module | :import | :test | :code

  @spec of(struct()) :: kind()
  def of(%DocNode{}), do: :doc
  def of(%AttributeNode{}), do: :attribute
  def of(%FunctionNode{}), do: :function
  def of(%ModuleNode{}), do: :module
  def of(%ImportNode{}), do: :import
  def of(%TestNode{}), do: :test
  def of(%CodeNode{}), do: :code
end
