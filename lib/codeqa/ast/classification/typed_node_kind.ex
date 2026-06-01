defmodule CodeQA.AST.Classification.TypedNodeKind do
  @moduledoc "Maps a typed node struct from `NodeClassifier` to its kind atom."

  alias CodeQA.AST.Nodes.{
    AttributeNode,
    CodeNode,
    DocNode,
    FunctionNode,
    ImportNode,
    ModuleNode,
    TestNode
  }

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
