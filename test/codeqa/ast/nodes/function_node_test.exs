defmodule CodeQA.AST.Nodes.FunctionNodeTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Nodes.{FunctionNode, ModuleNode}
  alias CodeQA.AST.Classification.NodeProtocol

  describe "FunctionNode" do
    setup do
      node = %FunctionNode{
        tokens: [:a],
        line_count: 5,
        children: [],
        start_line: 10,
        end_line: 14,
        label: "foo.ex:10",
        name: "calculate",
        arity: 2,
        visibility: :public
      }

      %{node: node}
    end

    test "implements NodeProtocol", %{node: node} do
      assert NodeProtocol.tokens(node) == [:a]
      assert NodeProtocol.line_count(node) == 5
      assert NodeProtocol.start_line(node) == 10
    end

    test "specific fields are accessible", %{node: node} do
      assert node.name == "calculate"
      assert node.arity == 2
      assert node.visibility == :public
    end

    test "specific fields default to nil" do
      node = %FunctionNode{tokens: [], line_count: 0, children: []}
      assert node.name == nil
      assert node.arity == nil
      assert node.visibility == nil
    end
  end

  describe "ModuleNode" do
    test "implements NodeProtocol" do
      node = %ModuleNode{
        tokens: [:m],
        line_count: 20,
        children: [],
        start_line: 1,
        end_line: 20,
        label: nil,
        name: "MyApp.Foo",
        kind: :module
      }

      assert NodeProtocol.tokens(node) == [:m]
      assert node.name == "MyApp.Foo"
      assert node.kind == :module
    end

    test "specific fields default to nil" do
      node = %ModuleNode{tokens: [], line_count: 0, children: []}
      assert node.name == nil
      assert node.kind == nil
    end
  end
end
