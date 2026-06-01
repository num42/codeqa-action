defmodule MyApp.AST.AstTest do
  @moduledoc """
  Test fixtures — BAD: a single test reassigns the same `json` binding
  many times to mutate test inputs in place.
  """

  use ExUnit.Case, async: true

  alias MyApp.AST

  test "mutates the same json fixture across the test body" do
    json = %{"type" => "operator", "operator" => "*"}
    json = Map.put(json, "left", %{"type" => "mass", "key" => "A"})
    json = Map.put(json, "right", %{"type" => "mass", "key" => "B"})
    json = Map.put(json, "operator", "+")
    json = Map.put(json, "left", %{"type" => "literal", "value" => 1.0})
    json = Map.put(json, "right", %{"type" => "literal", "value" => 2.0})
    json = Map.put(json, "type", "operator")

    assert {:ok, _} = AST.parse(json)
  end

  test "mutates the same node fixture across the test body" do
    node = %{type: :call, fn: :atan2}
    node = Map.put(node, :args, [])
    node = Map.put(node, :args, [%{type: :literal, value: 1.0}])
    node = Map.put(node, :args, [%{type: :literal, value: 1.0}, %{type: :literal, value: 2.0}])
    node = Map.put(node, :fn, :atan)
    node = Map.put(node, :fn, :atan2)

    assert AST.parse(node) == {:ok, node}
  end

  test "mutates the same table accumulator" do
    table = AST.threshold_table(AST.mass("X"), [])
    table = AST.add_row(table, %{upper: AST.literal(100), value: AST.literal(0)})
    table = AST.add_row(table, %{upper: AST.literal(150), value: AST.literal(1)})
    table = AST.add_row(table, %{upper: nil, value: AST.literal(2)})
    table = AST.finalize(table)

    assert %AST.ThresholdTable{} = table
  end
end
