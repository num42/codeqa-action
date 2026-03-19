defmodule CodeQA.AST.Signals.Structural.BlankLineSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.BlankLineSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang

  defp split_values(code, lang_mod) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%BlankLineSignal{}], lang_mod)
    for {_src, :split, :blank_split, v} <- emissions, do: v
  end

  test "no splits for single block" do
    assert split_values("def foo\n  x\nend\n", ElixirLang) == []
  end

  test "emits split after blank line following block-end token" do
    splits = split_values("def foo\n  x\nend\n\n\ndef bar\n  y\nend\n", ElixirLang)
    assert length(splits) == 1
  end

  test "no split when blank line does not follow block-end token" do
    assert split_values("x = 1\n\n\ny = 2\n", ElixirLang) == []
  end

  test "group is :split" do
    assert Signal.group(%BlankLineSignal{}) == :split
  end

  test "source is BlankLineSignal" do
    assert Signal.source(%BlankLineSignal{}) == BlankLineSignal
  end
end
