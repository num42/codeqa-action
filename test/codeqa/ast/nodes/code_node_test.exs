defmodule CodeQA.AST.Nodes.CodeNodeTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Nodes.{CodeNode, DocNode}
  alias CodeQA.AST.Classification.NodeProtocol

  @tokens [:a, :b, :c]

  describe "CodeNode" do
    setup do
      node = %CodeNode{
        tokens: @tokens,
        line_count: 2,
        children: [],
        start_line: 1,
        end_line: 2,
        label: "f.ex:1"
      }

      %{node: node}
    end

    test "implements NodeProtocol", %{node: node} do
      assert NodeProtocol.tokens(node) == @tokens
      assert NodeProtocol.line_count(node) == 2
      assert NodeProtocol.children(node) == []
      assert NodeProtocol.start_line(node) == 1
      assert NodeProtocol.end_line(node) == 2
      assert NodeProtocol.label(node) == "f.ex:1"
    end

    test "all common fields default to nil except children" do
      node = %CodeNode{tokens: [], line_count: 0, children: []}
      assert NodeProtocol.start_line(node) == nil
      assert NodeProtocol.end_line(node) == nil
      assert NodeProtocol.label(node) == nil
    end
  end

  describe "DocNode" do
    test "implements NodeProtocol" do
      node = %DocNode{
        tokens: @tokens,
        line_count: 1,
        children: [],
        start_line: 5,
        end_line: 5,
        label: nil
      }

      assert NodeProtocol.tokens(node) == @tokens
      assert NodeProtocol.children(node) == []
    end
  end
end
