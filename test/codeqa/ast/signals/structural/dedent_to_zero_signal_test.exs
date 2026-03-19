defmodule CodeQA.AST.Signals.Structural.DedentToZeroSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.DedentToZeroSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer

  defp split_count(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%DedentToZeroSignal{}], [])
    length(for {_src, :split, :dedent_split, _v} <- emissions, do: true)
  end

  test "no split in a single flat block (no indentation change)" do
    code = "foo\nbar\nbaz\n"
    assert split_count(code) == 0
  end

  test "emits split when first token of a new line at indent 0 after indented content" do
    code = "def foo:\n  return 1\ndef bar:\n"
    assert split_count(code) == 1
  end

  test "does NOT emit when returning to indent 0 from same-level content (no prior indent)" do
    code = "foo\nbar\n"
    assert split_count(code) == 0
  end

  test "does NOT emit at the very start of file (seen_content == false)" do
    code = "foo\n  bar\n"
    # The very first line has no prior indent, so no split should fire
    assert split_count(code) == 0
  end

  test "handles multiple indented blocks with splits" do
    code = "foo:\n  x = 1\nbar:\n  y = 2\nbaz:\n"
    # split at "bar" and "baz"
    assert split_count(code) == 2
  end

  test "does NOT split if current line also has indent (both lines indented)" do
    code = "foo:\n  x = 1\n  y = 2\n"
    assert split_count(code) == 0
  end

  test "emits split when a blank line separates an indented block from a new block at indent 0" do
    code = "def foo:\n  return 1\n\ndef bar:\n"
    assert split_count(code) == 1
  end

  test "group/1 returns :split" do
    assert Signal.group(%DedentToZeroSignal{}) == :split
  end
end
