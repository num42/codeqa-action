defmodule CodeQA.AST.Signals.Structural.CommentDividerSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.CommentDividerSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang
  alias CodeQA.Languages.Code.Vm.Java
  alias CodeQA.Languages.Data.Sql

  defp split_values(code, lang_mod) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%CommentDividerSignal{}], lang_mod)
    for {_src, :split, :comment_divider_split, v} <- emissions, do: v
  end

  test "no split for first divider comment (seen_content == false at start of file)" do
    assert split_values("# ---\n", ElixirLang) == []
  end

  test "emits split at # --- after prior content" do
    splits = split_values("x = 1\n# ---\ny = 2\n", ElixirLang)
    assert length(splits) == 1
  end

  test "emits split at // === after prior content" do
    splits = split_values("x = 1\n// ===\ny = 2\n", Java)
    assert length(splits) == 1
  end

  test "emits split at -- --- after prior content (SQL style)" do
    splits = split_values("x = 1\n-- ---\ny = 2\n", Sql)
    assert length(splits) == 1
  end

  test "does NOT emit for # followed by identifier (real comment)" do
    assert split_values("x = 1\n# This is a real comment\n", ElixirLang) == []
  end

  test "does NOT emit when # is not at line start" do
    assert split_values("x = 1\nx # ---\n", ElixirLang) == []
  end

  test "does NOT emit for indented divider comment (inside a block)" do
    assert split_values("x = 1\n  # ---\n", ElixirLang) == []
  end

  test "group is :split" do
    assert Signal.group(%CommentDividerSignal{}) == :split
  end
end
