defmodule CodeQA.AST.NodeProtocolTest.FakeNode do
  defstruct [:children, :end_line, :label, :line_count, :start_line, :tokens]

  defimpl CodeQA.AST.Classification.NodeProtocol do
    alias CodeQA.AST.Classification.NodeProtocol

    def tokens(n), do: n.tokens
    def line_count(n), do: n.line_count
    def children(n), do: n.children
    def start_line(n), do: n.start_line
    def end_line(n), do: n.end_line
    def label(n), do: n.label

    def flat_tokens(n) do
      if n.children |> Enum.empty?(),
        do: n.tokens,
        else: n.children |> Enum.flat_map(&NodeProtocol.flat_tokens/1)
    end
  end
end

defmodule CodeQA.AST.NodeProtocolTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeProtocol
  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.NodeProtocolTest.FakeNode

  @node %FakeNode{
    children: [],
    end_line: 3,
    label: "foo.ex:1",
    line_count: 3,
    start_line: 1,
    tokens: [:a, :b]
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
    test "leaf node returns own tokens" do
      leaf = %Node{children: [], line_count: 1, tokens: [:a, :b]}
      assert NodeProtocol.flat_tokens(leaf) == [:a, :b]
    end

    test "non-leaf node returns flattened descendant tokens" do
      child_a = %Node{children: [], line_count: 1, tokens: [:a]}
      child_b = %Node{children: [], line_count: 1, tokens: [:b, :c]}
      parent = %Node{children: [child_a, child_b], line_count: 2, tokens: [:x]}
      assert NodeProtocol.flat_tokens(parent) == [:a, :b, :c]
    end

    test "deeply nested node returns all leaf tokens" do
      leaf = %Node{children: [], line_count: 1, tokens: [:z]}
      mid = %Node{children: [leaf], line_count: 1, tokens: [:y]}
      root = %Node{children: [mid], line_count: 2, tokens: [:x]}
      assert NodeProtocol.flat_tokens(root) == [:z]
    end
  end

  describe "Node implements NodeProtocol" do
    setup do
      node = %Node{
        children: [],
        end_line: 3,
        label: "f.ex:1",
        line_count: 3,
        start_line: 1,
        tokens: [:x, :y]
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
