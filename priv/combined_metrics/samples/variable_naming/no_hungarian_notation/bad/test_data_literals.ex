defmodule MyApp.AST.AstTest do
  @moduledoc """
  Test fixtures — BAD: bindings prefixed with their type
  (`mapJson`, `arrArgs`, `strKey`, `intValue`).
  """

  use ExUnit.Case, async: true

  alias MyApp.AST

  test "parses an atan2 call" do
    mapNode = %{
      strType: "call",
      strFn: "atan2",
      arrArgs: [%{strType: "literal", floatValue: 1.0}, %{strType: "literal", floatValue: 2.0}]
    }

    assert AST.parse(mapNode) == {:ok, mapNode}
  end

  test "parses a multiplication operator" do
    mapJson = %{
      "strType" => "operator",
      "strOperator" => "*",
      "mapLeft" => %{"strType" => "mass", "strKey" => "A"},
      "mapRight" => %{"strType" => "mass", "strKey" => "B"}
    }

    assert {:ok, _} = AST.parse(mapJson)
  end

  test "builds a threshold table from multi-line args" do
    objTable =
      AST.threshold_table(AST.mass("WOHNFLAECHE_GESAMT"), [
        %{intUpper: AST.literal(150), intValue: AST.literal(1)},
        %{intUpper: nil, intValue: AST.literal(2)}
      ])

    assert %AST.ThresholdTable{} = objTable
  end
end
