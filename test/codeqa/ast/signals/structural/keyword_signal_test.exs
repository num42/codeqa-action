defmodule CodeQA.AST.Signals.Structural.KeywordSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Structural.KeywordSignal
  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang

  defp split_values(code, lang_mod) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%KeywordSignal{}], lang_mod)
    for {_src, :split, :keyword_split, v} <- emissions, do: v
  end

  test "no split for single def" do
    assert split_values("def foo\n  x\nend\n", ElixirLang) == []
  end

  test "emits split at second def keyword at depth 0 indent 0" do
    splits = split_values("def foo\n  x\nend\ndef bar\n  y\nend\n", ElixirLang)
    assert length(splits) == 1
  end

  test "does not split on def inside a module (indented)" do
    splits = split_values("defmodule Foo do\n  def foo, do: 1\nend\n", ElixirLang)
    assert splits == []
  end

  test "does not split on keyword inside brackets" do
    splits = split_values("foo(def, bar)\n", ElixirLang)
    assert splits == []
  end

  test "group is :split" do
    assert Signal.group(%KeywordSignal{}) == :split
  end
end
