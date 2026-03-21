defmodule CodeQA.AST.Signals.Structural.DecoratorSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Structural.DecoratorSignal

  defp split_values(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%DecoratorSignal{}], [])
    for {_src, :split, :decorator_split, v} <- emissions, do: v
  end

  test "no split for first @ (seen_content == false at start of file)" do
    assert split_values("@decorator\ndef foo() {}\n") == []
  end

  test "emits split at second @decorator after content" do
    splits = split_values("@decorator\ndef foo() {}\n@decorator\ndef bar() {}\n")
    assert length(splits) == 1
  end

  test "does not emit when @ is inside brackets" do
    splits = split_values("@decorator\ndef foo(@param x) {}\n")
    assert splits == []
  end

  test "does not emit when @ is not at line start (mid-expression)" do
    splits = split_values("@decorator\ndef foo() { x@y }\n")
    assert splits == []
  end

  test "emits split for Rust #[ pattern at line start after content" do
    splits = split_values("#[derive(Debug)]\nstruct Foo {}\n#[derive(Clone)]\nstruct Bar {}\n")
    assert length(splits) == 1
  end

  test "does not emit for # at line start when next token is not [" do
    splits = split_values("@decorator\ndef foo() {}\n# comment\ndef bar() {}\n")
    assert splits == []
  end

  test "group is :split" do
    assert Signal.group(%DecoratorSignal{}) == :split
  end
end
