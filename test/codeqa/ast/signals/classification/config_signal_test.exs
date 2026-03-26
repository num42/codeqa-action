defmodule CodeQA.AST.Signals.Classification.ConfigSignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Signals.Classification.ConfigSignal

  defp run(tokens), do: SignalStream.run(tokens, [%ConfigSignal{}], []) |> List.flatten()
  defp t(content, kind \\ "<ID>"), do: %{kind: kind, content: content, line: 1, col: 0}

  test "emits config_vote for 'config' keyword at indent 0" do
    emissions = run([t("config"), t(":app"), t(","), t("key:"), t("val")])
    assert [{ConfigSignal, :classification, :config_vote, 3}] = emissions
  end

  test "emits config_vote for 'configure' keyword" do
    emissions = run([t("configure")])
    assert [{ConfigSignal, :classification, :config_vote, 3}] = emissions
  end

  test "does not emit when indented" do
    emissions = run([t("<WS>", "<WS>"), t("config")])
    assert emissions == []
  end

  test "does not emit for 'config' inside brackets" do
    tokens = [t("(", "("), t("config"), t(")", ")")]
    assert run(tokens) == []
  end
end
