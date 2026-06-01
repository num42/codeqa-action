defmodule CodeQA.AST.Classification.TypedNodeKindTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.TypedNodeKind

  alias CodeQA.AST.Nodes.{
    AttributeNode,
    CodeNode,
    DocNode,
    FunctionNode,
    ImportNode,
    ModuleNode,
    TestNode
  }

  test "maps each typed node struct to its kind atom" do
    assert TypedNodeKind.of(%DocNode{}) == :doc
    assert TypedNodeKind.of(%AttributeNode{}) == :attribute
    assert TypedNodeKind.of(%FunctionNode{}) == :function
    assert TypedNodeKind.of(%ModuleNode{}) == :module
    assert TypedNodeKind.of(%ImportNode{}) == :import
    assert TypedNodeKind.of(%TestNode{}) == :test
    assert TypedNodeKind.of(%CodeNode{}) == :code
  end
end
