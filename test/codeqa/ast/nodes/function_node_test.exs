defmodule CodeQA.AST.Nodes.FunctionNodeTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Nodes.FunctionNode
  alias CodeQA.AST.Nodes.ModuleNode

  describe "FunctionNode" do
    setup do
      node = %FunctionNode{
        arity: 2,
        children: [],
        end_line: 14,
        label: "foo.ex:10",
        line_count: 5,
        name: "calculate",
        start_line: 10,
        tokens: [:a],
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
      node = %FunctionNode{children: [], line_count: 0, tokens: []}
      assert node.name == nil
      assert node.arity == nil
      assert node.visibility == nil
    end
  end

  describe "ModuleNode" do
    test "implements NodeProtocol" do
      node = %ModuleNode{
        children: [],
        end_line: 20,
        kind: :module,
        label: nil,
        line_count: 20,
        name: "MyApp.Foo",
        start_line: 1,
        tokens: [:m]
      }

      assert NodeProtocol.tokens(node) == [:m]
      assert node.name == "MyApp.Foo"
      assert node.kind == :module
    end

    test "specific fields default to nil" do
      node = %ModuleNode{children: [], line_count: 0, tokens: []}
      assert node.name == nil
      assert node.kind == nil
    end
  end
end
