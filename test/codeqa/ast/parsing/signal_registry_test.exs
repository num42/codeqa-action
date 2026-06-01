defmodule CodeQA.AST.Parsing.SignalRegistryTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Parsing.SignalRegistry

  test "new/0 returns empty registry" do
    r = SignalRegistry.new()
    assert r.structural == []
    assert r.classification == []
  end

  test "register_structural/2 appends signal" do
    alias CodeQA.AST.Signals.Structural.BlankLineSignal
    r = SignalRegistry.new() |> SignalRegistry.register_structural(%BlankLineSignal{})
    assert length(r.structural) == 1
  end

  test "register_classification/2 appends signal" do
    alias CodeQA.AST.Signals.Classification.FunctionSignal
    r = SignalRegistry.new() |> SignalRegistry.register_classification(%FunctionSignal{})
    assert length(r.classification) == 1
  end

  test "default/0 includes all built-in signals" do
    r = SignalRegistry.default()
    assert length(r.structural) >= 4
    assert length(r.classification) >= 6
  end

  test "default/0 has exactly 10 classification signals" do
    r = SignalRegistry.default()
    assert length(r.classification) == 10
  end
end
