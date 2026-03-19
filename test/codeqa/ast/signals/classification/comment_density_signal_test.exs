defmodule CodeQA.AST.Signals.Classification.CommentDensitySignalTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Signals.Classification.CommentDensitySignal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.Languages.Code.Scripting.Python
  alias CodeQA.Languages.Unknown

  defp run(tokens, lang_mod \\ Unknown),
    do: SignalStream.run(tokens, [%CommentDensitySignal{}], lang_mod) |> List.flatten()

  defp t(content, kind \\ "<ID>"), do: %{kind: kind, content: content, line: 1, col: 0}
  defp nl, do: %{kind: "<NL>", content: "\n", line: 1, col: 0}
  defp on_line(tokens, line), do: Enum.map(tokens, &%{&1 | line: line})

  test "votes comment when >60% of lines start with #" do
    tokens =
      on_line([t("#"), t("license")], 1) ++
        [nl()] ++
        on_line([t("#"), t("copyright")], 2) ++
        [nl()] ++
        on_line([t("#"), t("author")], 3) ++
        [nl()] ++
        on_line([t("def"), t("foo")], 4)

    emissions = run(tokens, Python)
    assert [{CommentDensitySignal, :classification, :comment_vote, _}] = emissions
  end

  test "does not vote when comment density is low" do
    tokens =
      on_line([t("def"), t("foo")], 1) ++
        [nl()] ++
        on_line([t("#"), t("note")], 2)

    assert run(tokens, Python) == []
  end

  test "does not vote when no comment_prefixes provided" do
    tokens =
      on_line([t("#"), t("comment")], 1) ++
        [nl()] ++
        on_line([t("#"), t("comment")], 2)

    assert run(tokens, Unknown) == []
  end
end
