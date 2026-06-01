defmodule CodeQA.AST.Signals.Classification.TypeSignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Classification.TypeSignal

  defp run(tokens), do: SignalStream.run(tokens, [%TypeSignal{}], []) |> List.flatten()

  defp token(content, kind \\ "<ID>"), do: %{kind: kind, content: content, line: 1, col: 0}

  test "emits type_vote weight 3 for @type at indent 0" do
    emissions = run([token("@", "@"), token("type"), token("t"), token("::"), token("integer")])
    assert [{TypeSignal, :classification, :type_vote, 3}] = emissions
  end

  test "emits type_vote for @typep" do
    emissions = run([token("@", "@"), token("typep"), token("t"), token("::")])
    assert [{TypeSignal, :classification, :type_vote, 3}] = emissions
  end

  test "emits type_vote for @opaque" do
    emissions = run([token("@", "@"), token("opaque"), token("t"), token("::")])
    assert [{TypeSignal, :classification, :type_vote, 3}] = emissions
  end

  test "does not emit for @spec" do
    emissions = run([token("@", "@"), token("spec"), token("foo"), token("()")])
    assert emissions == []
  end

  test "does not emit for @type inside indented block" do
    emissions = run([token("<WS>", "<WS>"), token("@", "@"), token("type"), token("t")])
    assert emissions == []
  end

  test "emits at most one vote" do
    tokens = [
      token("@", "@"),
      token("type"),
      token("a"),
      token("<NL>", "<NL>"),
      token("@", "@"),
      token("typep"),
      token("b")
    ]

    emissions = run(tokens)
    assert length(emissions) == 1
  end
end
