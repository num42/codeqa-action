defmodule CodeQA.Metrics.BlockRules.BlankLineRuleTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.BlockRules.BlankLineRule

  test "no splits for single block (one newline)" do
    tokens = ["<ID>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == []
  end

  test "detects split after two consecutive <NL>" do
    tokens = ["<ID>", "<NL>", "<NL>", "<ID>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == [{:split, 3}]
  end

  test "detects split with whitespace-only blank line between <NL>s" do
    tokens = ["<ID>", "<NL>", "<WS>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == [{:split, 4}]
  end

  test "no split at start of file even if preceded by blank lines" do
    tokens = ["<NL>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == []
  end

  test "detects multiple splits in a longer stream" do
    # block1 <NL><NL> block2 <NL><NL> block3
    tokens = ["<ID>", "<NL>", "<NL>", "<ID>", "<NL>", "<NL>", "<ID>"]
    splits = BlankLineRule.detect(tokens, [])
    assert length(splits) == 2
  end

  test "three <NL> in a row still produces one split" do
    tokens = ["<ID>", "<NL>", "<NL>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == [{:split, 4}]
  end
end
