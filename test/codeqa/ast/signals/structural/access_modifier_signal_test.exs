defmodule CodeQA.AST.Signals.Structural.AccessModifierSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.AccessModifierSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Languages.Code.Vm.Java

  defp split_values(code, lang_mod) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%AccessModifierSignal{}], lang_mod)
    for {_src, :split, :access_modifier_split, v} <- emissions, do: v
  end

  test "no split for first modifier (seen_content == false)" do
    assert split_values("public void foo() {}\n", Java) == []
  end

  test "emits split at second public modifier after content" do
    splits = split_values("public void foo() {}\npublic void bar() {}\n", Java)
    assert length(splits) == 1
  end

  test "emits split at private modifier after content" do
    splits = split_values("public void foo() {}\nprivate void bar() {}\n", Java)
    assert length(splits) == 1
  end

  test "does not split when modifier is inside brackets" do
    splits = split_values("public void foo(private int x) {}\n", Java)
    assert splits == []
  end

  test "does not split on identifier that matches modifier but is not at line start" do
    splits = split_values("public void foo() {}\nfoo.public.bar()\n", Java)
    assert splits == []
  end

  test "works at indent > 0 (unlike KeywordSignal)" do
    # Two indented public declarations, no enclosing brackets — should split
    splits = split_values("  public void foo() {}\n  public void bar() {}\n", Java)
    assert length(splits) == 1
  end

  test "group is :split" do
    assert Signal.group(%AccessModifierSignal{}) == :split
  end
end
