defmodule CodeQA.AST.Nodes.ImportNodeTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Nodes.{AttributeNode, ImportNode, TestNode}

  describe "ImportNode" do
    test "implements NodeProtocol" do
      node = %ImportNode{
        tokens: [:i],
        line_count: 1,
        children: [],
        start_line: 3,
        end_line: 3,
        label: nil,
        target: "MyApp.Repo"
      }

      assert NodeProtocol.tokens(node) == [:i]
      assert node.target == "MyApp.Repo"
    end

    test "target defaults to nil" do
      node = %ImportNode{tokens: [], line_count: 0, children: []}
      assert node.target == nil
    end
  end

  describe "AttributeNode" do
    test "implements NodeProtocol" do
      node = %AttributeNode{
        tokens: [:a],
        line_count: 1,
        children: [],
        start_line: 2,
        end_line: 2,
        label: nil,
        name: "moduledoc",
        kind: :annotation
      }

      assert NodeProtocol.tokens(node) == [:a]
      assert node.name == "moduledoc"
      assert node.kind == :annotation
    end

    test "supports :typespec kind" do
      node = %AttributeNode{tokens: [], line_count: 0, children: [], kind: :typespec}
      assert node.kind == :typespec
    end
  end

  describe "TestNode" do
    test "implements NodeProtocol" do
      node = %TestNode{
        tokens: [:t],
        line_count: 4,
        children: [],
        start_line: 10,
        end_line: 13,
        label: nil,
        description: "returns the sum"
      }

      assert NodeProtocol.tokens(node) == [:t]
      assert node.description == "returns the sum"
    end

    test "description defaults to nil" do
      node = %TestNode{tokens: [], line_count: 0, children: []}
      assert node.description == nil
    end
  end
end
