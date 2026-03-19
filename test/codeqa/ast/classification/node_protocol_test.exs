defmodule CodeQA.AST.NodeProtocolTest.FakeNode do
  defstruct [:tokens, :line_count, :children, :start_line, :end_line, :label]

  defimpl CodeQA.AST.Classification.NodeProtocol do
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
end

defmodule CodeQA.AST.NodeProtocolTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.NodeProtocolTest.FakeNode

  @node %FakeNode{
    tokens: [:a, :b],
    line_count: 3,
    children: [],
    start_line: 1,
    end_line: 3,
    label: "foo.ex:1"
  }

  test "tokens/1" do
    assert NodeProtocol.tokens(@node) == [:a, :b]
  end

  test "line_count/1" do
    assert NodeProtocol.line_count(@node) == 3
  end

  test "children/1" do
    assert NodeProtocol.children(@node) == []
  end

  test "start_line/1" do
    assert NodeProtocol.start_line(@node) == 1
  end

  test "end_line/1" do
    assert NodeProtocol.end_line(@node) == 3
  end

  test "label/1" do
    assert NodeProtocol.label(@node) == "foo.ex:1"
  end

  describe "flat_tokens/1" do
    alias CodeQA.AST.Enrichment.Node

    test "leaf node returns own tokens" do
      leaf = %Node{tokens: [:a, :b], line_count: 1, children: []}
      assert NodeProtocol.flat_tokens(leaf) == [:a, :b]
    end

    test "non-leaf node returns flattened descendant tokens" do
      child_a = %Node{tokens: [:a], line_count: 1, children: []}
      child_b = %Node{tokens: [:b, :c], line_count: 1, children: []}
      parent = %Node{tokens: [:x], line_count: 2, children: [child_a, child_b]}
      assert NodeProtocol.flat_tokens(parent) == [:a, :b, :c]
    end

    test "deeply nested node returns all leaf tokens" do
      leaf = %Node{tokens: [:z], line_count: 1, children: []}
      mid = %Node{tokens: [:y], line_count: 1, children: [leaf]}
      root = %Node{tokens: [:x], line_count: 2, children: [mid]}
      assert NodeProtocol.flat_tokens(root) == [:z]
    end
  end

  describe "Node implements NodeProtocol" do
    alias CodeQA.AST.Enrichment.Node

    setup do
      node = %Node{
        tokens: [:x, :y],
        line_count: 3,
        children: [],
        start_line: 1,
        end_line: 3,
        label: "f.ex:1"
      }

      %{node: node}
    end

    test "tokens/1", %{node: node} do
      assert NodeProtocol.tokens(node) == [:x, :y]
    end

    test "children/1", %{node: node} do
      assert NodeProtocol.children(node) == []
    end

    test "start_line/1", %{node: node} do
      assert NodeProtocol.start_line(node) == 1
    end

    test "label/1", %{node: node} do
      assert NodeProtocol.label(node) == "f.ex:1"
    end
  end
end
