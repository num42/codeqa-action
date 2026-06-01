defmodule CodeQA.AST.Signals.Classification.DataSignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Classification.DataSignal

  defp run(tokens), do: SignalStream.run(tokens, [%DataSignal{}], []) |> List.flatten()

  defp token(content, kind), do: %{col: 0, content: content, kind: kind, line: 1}
  defp string_kind_token(v), do: token(v, "<STR>")
  defp num(v), do: token(v, "<NUM>")
  defp id(v), do: token(v, "<ID>")

  test "votes data for high-literal token stream" do
    tokens = [string_kind_token("foo"), string_kind_token("bar"), num("1"), num("2"), id("key")]
    emissions = run(tokens)
    assert [{DataSignal, :classification, :data_vote, _}] = emissions
  end

  test "does not vote when control-flow keyword present" do
    tokens = [string_kind_token("foo"), id("if"), string_kind_token("bar")]
    assert run(tokens) == []
  end

  test "does not vote when literal ratio is low" do
    tokens = [id("foo"), id("bar"), id("baz"), string_kind_token("one")]
    assert run(tokens) == []
  end
end
