defmodule MyApp.AST.AstTest do
  @moduledoc """
  Test fixtures — BAD: bindings initialized to `""` and reassigned later.
  """

  use ExUnit.Case, async: true

  alias MyApp.AST

  test "constructs a node from empty-string sentinels" do
    type = ""
    fn_name = ""
    args = ""

    type = "call"
    fn_name = "atan2"
    args = [%{type: "literal", value: 1.0}, %{type: "literal", value: 2.0}]

    node = %{type: type, fn: fn_name, args: args}
    assert AST.parse(node) == {:ok, node}
  end

  test "builds an operator json from empty-string sentinels" do
    op = ""
    left_key = ""
    right_key = ""

    op = "*"
    left_key = "A"
    right_key = "B"

    json = %{
      "type" => "operator",
      "operator" => op,
      "left" => %{"type" => "mass", "key" => left_key},
      "right" => %{"type" => "mass", "key" => right_key}
    }

    assert {:ok, _} = AST.parse(json)
  end
end
