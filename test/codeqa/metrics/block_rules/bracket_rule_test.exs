defmodule CodeQA.Metrics.BlockRules.BracketRuleTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.BlockRules.BracketRule

  test "empty token list returns no enclosures" do
    assert BracketRule.detect([], []) == []
  end

  test "simple paren expression" do
    tokens = ["<ID>", "(", "<ID>", ")"]
    assert BracketRule.detect(tokens, []) == [{:enclosure, 1, 3}]
  end

  test "nested brackets produce one top-level enclosure" do
    tokens = ["(", "<ID>", "(", "<ID>", ")", ")"]
    assert BracketRule.detect(tokens, []) == [{:enclosure, 0, 5}]
  end

  test "two sibling bracket expressions" do
    tokens = ["(", "<ID>", ")", "(", "<ID>", ")"]
    assert BracketRule.detect(tokens, []) == [{:enclosure, 0, 2}, {:enclosure, 3, 5}]
  end

  test "unmatched open bracket produces no enclosure" do
    tokens = ["(", "<ID>"]
    assert BracketRule.detect(tokens, []) == []
  end

  test "supports square and curly brackets" do
    assert BracketRule.detect(["[", "<ID>", "]"], []) == [{:enclosure, 0, 2}]
    assert BracketRule.detect(["{", "<ID>", "}"], []) == [{:enclosure, 0, 2}]
  end
end
