defmodule CodeQA.AST.Nodes.ImportNodeTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Nodes.AttributeNode
  alias CodeQA.AST.Nodes.ImportNode
  alias CodeQA.AST.Nodes.TestNode

  describe "ImportNode" do
    test "implements NodeProtocol" do
      node = %ImportNode{
        children: [],
        end_line: 3,
        label: nil,
        line_count: 1,
        start_line: 3,
        target: "MyApp.Repo",
        tokens: [:i]
      }

      assert NodeProtocol.tokens(node) == [:i]
      assert node.target == "MyApp.Repo"
    end

    test "target defaults to nil" do
      node = %ImportNode{children: [], line_count: 0, tokens: []}
      assert node.target == nil
    end
  end

  describe "AttributeNode" do
    test "implements NodeProtocol" do
      node = %AttributeNode{
        children: [],
        end_line: 2,
        kind: :annotation,
        label: nil,
        line_count: 1,
        name: "moduledoc",
        start_line: 2,
        tokens: [:a]
      }

      assert NodeProtocol.tokens(node) == [:a]
      assert node.name == "moduledoc"
      assert node.kind == :annotation
    end

    test "supports :typespec kind" do
      node = %AttributeNode{children: [], kind: :typespec, line_count: 0, tokens: []}
      assert node.kind == :typespec
    end
  end

  describe "TestNode" do
    test "implements NodeProtocol" do
      node = %TestNode{
        children: [],
        description: "returns the sum",
        end_line: 13,
        label: nil,
        line_count: 4,
        start_line: 10,
        tokens: [:t]
      }

      assert NodeProtocol.tokens(node) == [:t]
      assert node.description == "returns the sum"
    end

    test "description defaults to nil" do
      node = %TestNode{children: [], line_count: 0, tokens: []}
      assert node.description == nil
    end
  end
end
