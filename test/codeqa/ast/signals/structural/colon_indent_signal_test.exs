defmodule CodeQA.AST.Signals.Structural.ColonIndentSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.ColonIndentSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.Languages.Code.Scripting.Python

  defp enclosure_values(code, lang_mod \\ Python) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%ColonIndentSignal{}], lang_mod)
    for {_src, :enclosure, :colon_indent_enclosure, v} <- emissions, do: v
  end

  test "no enclosures for non-python language" do
    assert enclosure_values("def foo:\n    return 1\n", CodeQA.Languages.Unknown) ==
             []
  end

  test "emits enclosure for colon-indented block in python" do
    enclosures = enclosure_values("def foo:\n    return 1\n")
    assert enclosures != []
  end

  test "group is :enclosure" do
    assert Signal.group(%ColonIndentSignal{}) == :enclosure
  end
end
