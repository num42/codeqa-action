defmodule CodeQA.AST.Signals.Classification.TypeSignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Signals.Classification.TypeSignal
  alias CodeQA.AST.Parsing.SignalStream

  defp run(tokens), do: SignalStream.run(tokens, [%TypeSignal{}], []) |> List.flatten()

  defp t(content, kind \\ "<ID>"), do: %{kind: kind, content: content, line: 1, col: 0}

  test "emits type_vote weight 3 for @type at indent 0" do
    emissions = run([t("@", "@"), t("type"), t("t"), t("::"), t("integer")])
    assert [{TypeSignal, :classification, :type_vote, 3}] = emissions
  end

  test "emits type_vote for @typep" do
    emissions = run([t("@", "@"), t("typep"), t("t"), t("::")])
    assert [{TypeSignal, :classification, :type_vote, 3}] = emissions
  end

  test "emits type_vote for @opaque" do
    emissions = run([t("@", "@"), t("opaque"), t("t"), t("::")])
    assert [{TypeSignal, :classification, :type_vote, 3}] = emissions
  end

  test "does not emit for @spec" do
    emissions = run([t("@", "@"), t("spec"), t("foo"), t("()")])
    assert emissions == []
  end

  test "does not emit for @type inside indented block" do
    emissions = run([t("<WS>", "<WS>"), t("@", "@"), t("type"), t("t")])
    assert emissions == []
  end

  test "emits at most one vote" do
    tokens = [t("@", "@"), t("type"), t("a"), t("<NL>", "<NL>"), t("@", "@"), t("typep"), t("b")]
    emissions = run(tokens)
    assert length(emissions) == 1
  end
end
