defmodule CodeQA.AST.SignalStreamTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.Support.CounterSignal

  defp tok(kind, content), do: %Token{kind: kind, content: content, line: 1, col: 0}

  test "returns one emission list per signal" do
    tokens = [tok("<ID>", "foo"), tok("<NL>", "\n"), tok("<ID>", "bar")]
    results = SignalStream.run(tokens, [%CounterSignal{}], [])
    assert length(results) == 1
  end

  test "emissions list contains all emitted values from the signal" do
    tokens = [tok("<ID>", "foo"), tok("<NL>", "\n"), tok("<ID>", "bar")]

    [
      [
        {CodeQA.Support.CounterSignal, :test, :id_seen, 0},
        {CodeQA.Support.CounterSignal, :test, :id_seen, 2}
      ]
    ] =
      SignalStream.run(tokens, [%CounterSignal{}], [])
  end

  test "non-emitting tokens produce no entries" do
    tokens = [tok("<NL>", "\n"), tok("<NL>", "\n")]
    [[]] = SignalStream.run(tokens, [%CounterSignal{}], [])
  end

  test "multiple signals run independently" do
    tokens = [tok("<ID>", "x")]
    results = SignalStream.run(tokens, [%CounterSignal{}, %CounterSignal{}], [])
    assert length(results) == 2
  end

  test "empty token stream returns empty emissions per signal" do
    results = SignalStream.run([], [%CounterSignal{}], [])
    assert results == [[]]
  end
end
