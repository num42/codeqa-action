defmodule CodeQA.AST.Signals.Classification.DataSignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Signals.Classification.DataSignal
  alias CodeQA.AST.Parsing.SignalStream

  defp run(tokens), do: SignalStream.run(tokens, [%DataSignal{}], []) |> List.flatten()

  defp t(content, kind), do: %{kind: kind, content: content, line: 1, col: 0}
  defp str(v), do: t(v, "<STR>")
  defp num(v), do: t(v, "<NUM>")
  defp id(v), do: t(v, "<ID>")

  test "votes data for high-literal token stream" do
    tokens = [str("foo"), str("bar"), num("1"), num("2"), id("key")]
    emissions = run(tokens)
    assert [{DataSignal, :classification, :data_vote, _}] = emissions
  end

  test "does not vote when control-flow keyword present" do
    tokens = [str("foo"), id("if"), str("bar")]
    assert run(tokens) == []
  end

  test "does not vote when literal ratio is low" do
    tokens = [id("foo"), id("bar"), id("baz"), str("one")]
    assert run(tokens) == []
  end
end
