defmodule CodeQA.AST.Signals.Classification.DataSignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Classification.DataSignal

  defp run(tokens), do: SignalStream.run(tokens, [%DataSignal{}], []) |> List.flatten()

  defp token(content, kind), do: %{kind: kind, content: content, line: 1, col: 0}
  defp str_token(v), do: token(v, "<STR>")
  defp num(v), do: token(v, "<NUM>")
  defp id(v), do: token(v, "<ID>")

  test "votes data for high-literal token stream" do
    tokens = [str_token("foo"), str_token("bar"), num("1"), num("2"), id("key")]
    emissions = run(tokens)
    assert [{DataSignal, :classification, :data_vote, _}] = emissions
  end

  test "does not vote when control-flow keyword present" do
    tokens = [str_token("foo"), id("if"), str_token("bar")]
    assert run(tokens) == []
  end

  test "does not vote when literal ratio is low" do
    tokens = [id("foo"), id("bar"), id("baz"), str_token("one")]
    assert run(tokens) == []
  end
end
