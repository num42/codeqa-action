defmodule CodeQA.AST.Signals.Structural.BracketSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Structural.BracketSignal

  defp enclosure_values(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%BracketSignal{}], [])
    for {_src, :enclosure, :bracket_enclosure, v} <- emissions, do: v
  end

  test "no enclosures for code without brackets" do
    assert enclosure_values("foo\n") == []
  end

  test "emits enclosure for a single bracketed expression" do
    enclosures = enclosure_values("foo(a, b)\n")
    assert length(enclosures) == 1
  end

  test "emits only outermost enclosure for nested brackets" do
    enclosures = enclosure_values("foo(bar(x))\n")
    assert length(enclosures) == 1
  end

  test "enclosure value is {start_idx, end_idx} tuple" do
    [{start, stop}] = enclosure_values("foo(a)\n")
    assert is_integer(start)
    assert is_integer(stop)
    assert stop > start
  end

  test "mismatched closing bracket is silently skipped" do
    assert enclosure_values("foo)\n") == []
  end

  test "group is :enclosure" do
    assert Signal.group(%BracketSignal{}) == :enclosure
  end
end
