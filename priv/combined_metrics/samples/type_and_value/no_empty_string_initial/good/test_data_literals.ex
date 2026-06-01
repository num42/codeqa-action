defmodule MyApp.AST.AstTest do
  @moduledoc """
  Test fixtures — GOOD: bindings start as fully-built data structures,
  not as `""` placeholders.
  """

  use ExUnit.Case, async: true

  alias MyApp.AST

  test "parses an atan2 call" do
    node = %{
      type: :call,
      fn: :atan2,
      args: [%{type: :literal, value: 1.0}, %{type: :literal, value: 2.0}]
    }

    assert AST.parse(node) == {:ok, node}
  end

  test "parses a multiplication operator" do
    json = %{
      "type" => "operator",
      "operator" => "*",
      "left" => %{"type" => "mass", "key" => "A"},
      "right" => %{"type" => "mass", "key" => "B"}
    }

    assert {:ok, _} = AST.parse(json)
  end

  test "builds a threshold table from multi-line args" do
    table =
      AST.threshold_table(AST.mass("WOHNFLAECHE_GESAMT"), [
        %{upper: AST.literal(150), value: AST.literal(1)},
        %{upper: nil, value: AST.literal(2)}
      ])

    assert %AST.ThresholdTable{} = table
  end
end
