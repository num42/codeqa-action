defmodule CodeQA.Metrics.BlockRules.ColonIndentationRuleTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.BlockRules.ColonIndentationRule

  test "empty token list returns no enclosures" do
    assert ColonIndentationRule.detect([], []) == []
  end

  test "detects indented block after colon" do
    # def foo:        → ["<ID>", "<ID>", ":", "<NL>"]  (indices 0-3)
    #     body        → ["<WS>", "<WS>", "<ID>", "<NL>"]  (indices 4-7)
    # enclosure must start at index 6 (<ID> "body") and end at 6
    tokens = ["<ID>", "<ID>", ":", "<NL>", "<WS>", "<WS>", "<ID>", "<NL>"]
    result = ColonIndentationRule.detect(tokens, [])
    assert length(result) == 1
    [{:enclosure, s, e}] = result
    assert s == 6
    assert e == 6
  end

  test "no enclosure when nothing follows the colon at deeper indent" do
    tokens = ["<ID>", ":"]
    assert ColonIndentationRule.detect(tokens, []) == []
  end

  test "no enclosure when next line has same or lesser indent" do
    # if x:
    # same_indent_line
    tokens = ["<ID>", "<ID>", ":", "<NL>", "<ID>"]
    assert ColonIndentationRule.detect(tokens, []) == []
  end

  test "nested colons produce two enclosures" do
    # def foo:       (indent 0) → outer enclosure covers lines 2-4
    #   if x:        (indent 1) → inner enclosure covers line 3 only
    #     body       (indent 2)
    #   other        (indent 1) → closes inner; outer closed at end
    tokens = [
      "<ID>", "<ID>", ":", "<NL>",          # def foo:
      "<WS>", "<ID>", "<ID>", ":", "<NL>",  # if x:
      "<WS>", "<WS>", "<ID>", "<NL>",       # body
      "<WS>", "<ID>", "<NL>"                # other
    ]
    result = ColonIndentationRule.detect(tokens, [])
    assert length(result) == 2
  end
end
