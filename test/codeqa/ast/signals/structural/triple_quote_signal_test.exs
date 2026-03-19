defmodule CodeQA.AST.Signals.Structural.TripleQuoteSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.TripleQuoteSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer

  defp split_values(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%TripleQuoteSignal{}], [])
    for {_src, :split, :triple_split, v} <- emissions, do: v
  end

  test "no splits for plain code" do
    assert split_values("def foo\n  :ok\nend\n") == []
  end

  test "emits two splits for a complete heredoc" do
    code = "\"\"\"\nhello\n\"\"\"\n"
    splits = split_values(code)
    assert length(splits) == 2
  end

  test "emits one split for unclosed heredoc (mismatch tolerance)" do
    # single <DOC> token with no closing pair
    code = "\"\"\"\nhello\n"
    splits = split_values(code)
    assert length(splits) == 1
  end

  test "group is :split" do
    assert Signal.group(%TripleQuoteSignal{}) == :split
  end
end
