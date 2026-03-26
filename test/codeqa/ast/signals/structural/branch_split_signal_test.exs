defmodule CodeQA.AST.Signals.Structural.BranchSplitSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.{Signal, SignalStream}
  alias CodeQA.AST.Signals.Structural.BranchSplitSignal
  alias CodeQA.Languages.Code.Scripting.PHP
  alias CodeQA.Languages.Code.Scripting.Python
  alias CodeQA.Languages.Code.Scripting.Ruby
  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang
  alias CodeQA.Languages.Code.Vm.Java

  defp split_values(code, lang_mod) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%BranchSplitSignal{}], lang_mod)
    for {_src, :branch_split, :branch_split, v} <- emissions, do: v
  end

  test "group is :branch_split" do
    assert Signal.group(%BranchSplitSignal{}) == :branch_split
  end

  test "no split for code with no branch keywords" do
    assert split_values("x = 1\ny = 2\n", ElixirLang) == []
  end

  test "emits split at else after seen content" do
    splits = split_values("if x do\n  :a\nelse\n  :b\nend\n", ElixirLang)
    assert length(splits) == 1
  end

  test "emits split at elif" do
    splits = split_values("if x:\n  pass\nelif y:\n  pass\n", Python)
    assert length(splits) == 1
  end

  test "emits split at multiple branch keywords" do
    splits = split_values("if x do\n  :a\nelsif y\n  :b\nelse\n  :c\nend\n", Ruby)
    assert length(splits) == 2
  end

  test "does not emit at first keyword (no seen_content yet)" do
    splits = split_values("if x do\n  :a\nend\n", ElixirLang)
    assert splits == []
  end

  test "does not emit when keyword is inside brackets" do
    splits = split_values("foo(if x do 1 else 2 end)\n", ElixirLang)
    assert splits == []
  end

  test "emits split at rescue" do
    splits = split_values("try do\n  :ok\nrescue\n  _ -> :error\nend\n", ElixirLang)
    assert length(splits) == 1
  end

  test "emits split at cond branch" do
    splits = split_values("x = 1\ncond do\n  x -> :a\nend\n", ElixirLang)
    assert length(splits) == 1
  end

  test "emits split at except (Python)" do
    splits = split_values("try:\n  pass\nexcept ValueError:\n  pass\n", Python)
    assert length(splits) == 1
  end

  test "emits split at ensure (Elixir)" do
    splits =
      split_values(
        "try do\n  :ok\nrescue\n  _ -> :error\nensure\n  cleanup()\nend\n",
        ElixirLang
      )

    assert length(splits) == 2
  end

  test "emits split at elseif (PHP)" do
    splits = split_values("if x then\n  :a\nelseif y then\n  :b\nend\n", PHP)
    assert length(splits) == 1
  end

  test "emits split at case label (switch body)" do
    splits =
      split_values("switch x\n  case 1:\n    :a\n  case 2:\n    :b\nend\n", Java)

    assert splits != []
  end

  test "emits split at when keyword" do
    splits = split_values("x = 1\nwhen x > 0 do\n  :pos\nend\n", ElixirLang)
    assert length(splits) == 1
  end
end
