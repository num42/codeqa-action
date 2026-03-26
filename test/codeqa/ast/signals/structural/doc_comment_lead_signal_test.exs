defmodule CodeQA.AST.Signals.Structural.DocCommentLeadSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Structural.DocCommentLeadSignal

  defp split_values(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%DocCommentLeadSignal{}], [])
    for {_src, :split, :doc_comment_split, v} <- emissions, do: v
  end

  test "no split for first /// (seen_content == false at start of file)" do
    assert split_values("/// doc\n") == []
  end

  test "emits split at /// after prior content (Rust/C# doc comment)" do
    splits = split_values("fn foo() {}\n/// doc\n")
    assert length(splits) == 1
  end

  test "emits split at /** after prior content (Java/JS JSDoc)" do
    splits = split_values("function foo() {}\n/**\n * doc\n */\n")
    assert length(splits) == 1
  end

  test "does NOT emit for // followed by identifier (regular line comment)" do
    assert split_values("x = 1\n// regular comment\n") == []
  end

  test "does NOT emit for // that is not at line start" do
    assert split_values("x = 1\nx // doc\n") == []
  end

  test "does NOT emit for / at line start when next is not *" do
    assert split_values("x = 1\n/ something\n") == []
  end

  test "group is :split" do
    assert Signal.group(%DocCommentLeadSignal{}) == :split
  end
end
